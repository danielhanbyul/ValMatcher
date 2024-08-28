//
//  DMHomeView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/12/24.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import FirebaseFirestoreSwift
import UserNotifications

struct MessageListener {
    let listener: ListenerRegistration
    private(set) var countedMessageIDs: Set<String> = []

    mutating func isAlreadyCounted(messageID: String) -> Bool {
        return countedMessageIDs.contains(messageID)
    }

    mutating func markAsCounted(messageID: String) {
        countedMessageIDs.insert(messageID)
    }
}

struct DMHomeView: View {
    @State private var matches = [Chat]()
    @State private var currentUserID = Auth.auth().currentUser?.uid
    @State private var isEditing = false
    @State private var selectedMatches = Set<String>()
    @Binding var totalUnreadMessages: Int
    @State private var shouldSortChats = true
    @State private var receivedNewMessage = false
    @State private var selectedChat: Chat?
    @State private var showNotificationBanner = false
    @State private var bannerMessage = ""
    @State private var debounceTimer: Timer?
    @State private var isLoading = true
    @State private var messageListeners: [String: ListenerRegistration] = [:]

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            if isLoading {
                ProgressView("Loading...")
                    .foregroundColor(.white)
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(matches) { match in
                                matchRow(match: match)
                            }
                        }
                    }
                    .padding(.top, 10)

                    if isEditing && !selectedMatches.isEmpty {
                        Button(action: deleteSelectedMatches) {
                            Text("Delete Selected")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                        .padding()
                    }
                }
                .animation(nil, value: matches)
            }
        }
        .navigationBarTitle("Messages", displayMode: .inline)
        .navigationBarItems(trailing: Button(action: { isEditing.toggle() }) {
            Text(isEditing ? "Done" : "Edit")
                .foregroundColor(.white)
        })
        .onAppear {
            if matches.isEmpty {
                loadMatches()
            }
        }
        .onDisappear {
            removeListeners()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            setupListeners()
        }
        .background(
            NavigationLink(
                destination: ChatView(matchID: selectedChat?.id ?? "", recipientName: getRecipientName(for: selectedChat))
                    .onAppear {
                        if let chat = selectedChat {
                            DispatchQueue.global().async {
                                markMessagesAsRead(for: chat)
                            }
                        }
                    }
                    .onDisappear {
                        refreshChatAfterReadingMessages()
                    },
                isActive: Binding(
                    get: { selectedChat != nil },
                    set: { if !$0 { selectedChat = nil } }
                )
            ) {
                EmptyView()
            }
        )
        .alert(isPresented: $showNotificationBanner) {
            Alert(title: Text("New Message"), message: Text(bannerMessage), dismissButton: .default(Text("OK")))
        }
    }

    @ViewBuilder
    private func matchRow(match: Chat) -> some View {
        HStack {
            Button(action: {
                selectedChat = match
                if let index = matches.firstIndex(where: { $0.id == match.id }) {
                    matches[index].hasUnreadMessages = false
                }
            }) {
                HStack {
                    if let currentUserID = currentUserID {
                        userImageView(currentUserID: currentUserID, match: match)
                    }

                    VStack(alignment: .leading) {
                        Text(getRecipientName(for: match))
                            .font(.custom("AvenirNext-Bold", size: 18))
                            .foregroundColor(.white)
                    }
                    .padding()
                    Spacer()

                    if match.hasUnreadMessages == true {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .padding(.trailing, 10)
                    }
                }
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.vertical, 5)
                .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)
            }
        }
    }

    private func getRecipientName(for match: Chat?) -> String {
        guard let match = match, let currentUserID = currentUserID else { return "Unknown User" }
        return currentUserID == match.user1 ? (match.user2Name ?? "Unknown User") : (match.user1Name ?? "Unknown User")
    }

    @ViewBuilder
    private func userImageView(currentUserID: String, match: Chat) -> some View {
        let currentUserImage = (currentUserID == match.user1 ? match.user2Image : match.user1Image) ?? "https://example.com/default-image.jpg"
        if let url = URL(string: currentUserImage) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 50, height: 50)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                case .failure:
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 50, height: 50)
        }
    }

    private func setupListeners() {
        loadMatches()

        NotificationCenter.default.addObserver(forName: Notification.Name("RefreshChatList"), object: nil, queue: .main) { [self] _ in
            self.debounceTimer?.invalidate()
            self.debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                self.loadMatches()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.shouldSortChats = true
        }
    }

    func loadMatches() {
        guard let currentUserID = currentUserID else {
            print("Error: currentUserID is nil")
            return
        }

        let db = Firestore.firestore()

        db.collection("matches")
            .whereField("user1", isEqualTo: currentUserID)
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error loading matches for user1: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("No documents for user1")
                    return
                }

                let newMatches = documents.compactMap { document -> Chat? in
                    do {
                        let match = try document.data(as: Chat.self)
                        return match
                    } catch {
                        print("Error decoding match for user1: \(error.localizedDescription)")
                        return nil
                    }
                }

                fetchUserNames(for: newMatches) { updatedMatches in
                    self.matches = self.mergeAndRemoveDuplicates(existingMatches: self.matches, newMatches: updatedMatches)
                    self.updateUnreadMessagesCount(from: self.matches)
                    self.addMessageListeners(for: updatedMatches)
                    print("Loaded matches for user1: \(self.matches)")
                }
            }

        db.collection("matches")
            .whereField("user2", isEqualTo: currentUserID)
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error loading matches for user2: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("No documents for user2")
                    return
                }

                let moreMatches = documents.compactMap { document -> Chat? in
                    do {
                        let match = try document.data(as: Chat.self)
                        return match
                    } catch {
                        print("Error decoding match for user2: \(error.localizedDescription)")
                        return nil
                    }
                }

                fetchUserNames(for: moreMatches) { updatedMatches in
                    self.matches = self.mergeAndRemoveDuplicates(existingMatches: self.matches, newMatches: updatedMatches)
                    self.updateUnreadMessagesCount(from: self.matches)
                    self.addMessageListeners(for: updatedMatches)
                    print("Loaded matches for user2: \(self.matches)")

                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                }
            }
    }

    private func fetchUserNames(for matches: [Chat], completion: @escaping ([Chat]) -> Void) {
        var updatedMatches = matches
        let dispatchGroup = DispatchGroup()

        for i in 0..<updatedMatches.count {
            if let currentUserID = currentUserID {
                dispatchGroup.enter()
                if updatedMatches[i].user1 == currentUserID {
                    if let user2 = updatedMatches[i].user2 {
                        Firestore.firestore().collection("users").document(user2).getDocument { document, error in
                            if let document = document, document.exists {
                                updatedMatches[i].user2Name = document.data()?["name"] as? String ?? "Unknown User"
                            } else {
                                updatedMatches[i].user2Name = "Unknown User"
                            }
                            dispatchGroup.leave()
                        }
                    }
                } else {
                    if let user1 = updatedMatches[i].user1 {
                        Firestore.firestore().collection("users").document(user1).getDocument { document, error in
                            if let document = document, document.exists {
                                updatedMatches[i].user1Name = document.data()?["name"] as? String ?? "Unknown User"
                            } else {
                                updatedMatches[i].user1Name = "Unknown User"
                            }
                            dispatchGroup.leave()
                        }
                    }
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            completion(updatedMatches)
        }
    }

    private func updateUnreadMessagesCount(from matches: [Chat]) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        var count = 0
        let group = DispatchGroup()

        var updatedMatches = matches

        for (index, match) in updatedMatches.enumerated() {
            guard let matchID = match.id else { continue }
            group.enter()
            Firestore.firestore().collection("matches").document(matchID).collection("messages")
                .order(by: "timestamp", descending: true)
                .getDocuments { messageSnapshot, error in
                    if let error = error {
                        print("Error fetching messages: \(error)")
                        group.leave()
                        return
                    }

                    let unreadCount = messageSnapshot?.documents.filter { document in
                        let senderID = document.data()["senderID"] as? String ?? ""
                        let isRead = document.data()["isRead"] as? Bool ?? true
                        return senderID != currentUserID && !isRead
                    }.count ?? 0

                    if unreadCount > 0 {
                        updatedMatches[index].hasUnreadMessages = true
                    } else {
                        updatedMatches[index].hasUnreadMessages = false
                    }

                    if let latestMessage = messageSnapshot?.documents.first {
                        updatedMatches[index].timestamp = latestMessage.data()["timestamp"] as? Timestamp
                    }

                    count += unreadCount
                    group.leave()
                }
        }

        group.notify(queue: .main) {
            self.totalUnreadMessages = count

            self.matches = updatedMatches.sorted {
                ($0.timestamp?.dateValue() ?? Date.distantPast) > ($1.timestamp?.dateValue() ?? Date.distantPast)
            }

            if self.receivedNewMessage {
                notifyUserOfNewMessages(count: count)
                self.receivedNewMessage = false
            }
        }
    }

    private func addMessageListeners(for matches: [Chat]) {
        guard let currentUserID = currentUserID else { return }
        let db = Firestore.firestore()

        for match in matches {
            guard let matchID = match.id else { continue }

            if messageListeners[matchID] == nil {
                let listener = db.collection("matches").document(matchID).collection("messages")
                    .order(by: "timestamp", descending: true)
                    .limit(to: 1)
                    .addSnapshotListener { snapshot, error in
                        if let error = error {
                            print("Error listening for new messages: \(error)")
                            return
                        }

                        guard let document = snapshot?.documents.first else { return }

                        let senderID = document.data()["senderID"] as? String ?? ""
                        let isRead = document.data()["isRead"] as? Bool ?? true

                        if senderID != currentUserID && !isRead {
                            DispatchQueue.main.async {
                                self.updateUnreadMessagesCount(from: self.matches)
                            }
                        }
                    }
                messageListeners[matchID] = listener
            }
        }
    }

    private func removeListeners() {
        for listener in messageListeners.values {
            listener.remove()
        }
        messageListeners.removeAll()
    }

    func deleteSelectedMatches() {
        for matchID in selectedMatches {
            if let index = matches.firstIndex(where: { $0.id == matchID }) {
                let match = matches[index]
                deleteMatch(match)
                matches.remove(at: index)
            }
        }
        selectedMatches.removeAll()
    }

    func deleteMatch(_ match: Chat) {
        guard let matchID = match.id else {
            print("Match ID is missing")
            return
        }

        let db = Firestore.firestore()
        db.collection("matches").document(matchID).delete { error in
            if let error = error {
                print("Error deleting match: \(error.localizedDescription)")
            } else {
                print("Match deleted successfully")
            }
        }
    }

    private func listenForUnreadMessages() {
        guard let currentUserID = currentUserID else {
            print("Error: User not authenticated")
            return
        }

        let db = Firestore.firestore()

        let matchQuery = db.collection("matches")
            .whereField("user1", isEqualTo: currentUserID)
            .whereField("user2", isEqualTo: currentUserID)

        matchQuery.addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error fetching matches: \(error)")
                return
            }

            var unreadCounts: [String: Int] = [:]
            var totalUnreadCount = 0

            snapshot?.documents.forEach { document in
                let matchID = document.documentID
                self.listenForNewMessages(in: db, matchID: matchID, currentUserID: currentUserID) { unreadCount, latestMessage in
                    let previousCount = unreadCounts[matchID] ?? 0
                    let difference = unreadCount - previousCount
                    totalUnreadCount += difference
                    unreadCounts[matchID] = unreadCount

                    if difference > 0 {
                        DispatchQueue.main.async {
                            self.shouldSortChats = true
                        }
                    }

                    DispatchQueue.main.async {
                        self.totalUnreadMessages = totalUnreadCount
                    }

                    if difference > 0 && UIApplication.shared.applicationState == .active {
                        self.receivedNewMessage = true
                        if let latestMessage = latestMessage, latestMessage.data()["senderID"] as? String != currentUserID {
                            self.showInAppNotification(for: latestMessage)
                        }
                    }
                }
            }
        }
    }

    private func listenForNewMessages(in db: Firestore, matchID: String, currentUserID: String, completion: @escaping (Int, QueryDocumentSnapshot?) -> Void) {
        let messageQuery = db.collection("matches").document(matchID).collection("messages")
            .order(by: "timestamp", descending: true)

        messageQuery.addSnapshotListener { messageSnapshot, error in
            if let error = error {
                print("Error fetching messages: \(error)")
                return
            }

            let unreadMessages = messageSnapshot?.documents.filter { document in
                let senderID = document.data()["senderID"] as? String ?? ""
                let isRead = document.data()["isRead"] as? Bool ?? true
                return senderID != currentUserID && !isRead
            }
            let latestMessage = messageSnapshot?.documents.first

            completion(unreadMessages?.count ?? 0, latestMessage)
        }
    }

    private func markMessagesAsRead(for match: Chat) {
        guard let matchID = match.id, let currentUserID = currentUserID else { return }
        let db = Firestore.firestore()

        let messagesQuery = db.collection("matches").document(matchID).collection("messages")
            .whereField("senderID", isNotEqualTo: currentUserID)
            .whereField("isRead", isEqualTo: false)

        messagesQuery.getDocuments { snapshot, error in
            if let error = error {
                print("Error marking messages as read: \(error.localizedDescription)")
                return
            }

            let batch = db.batch()
            snapshot?.documents.forEach { document in
                let messageRef = document.reference
                batch.updateData(["isRead": true], forDocument: messageRef)
            }

            batch.commit { error in
                if let error = error {
                    print("Error committing batch: \(error.localizedDescription)")
                }
            }
        }
    }

    private func refreshChatAfterReadingMessages() {
        guard let selectedChatID = selectedChat?.id else { return }

        if let index = matches.firstIndex(where: { $0.id == selectedChatID }) {
            matches[index].hasUnreadMessages = false
        }
    }

    private func notifyUserOfNewMessages(count: Int) {
        guard count > 0 else { return }
        if UIApplication.shared.applicationState != .active {
            let alertMessage = "You have \(count) new message(s)."
            showNotification(title: "New Message", body: alertMessage)
        }
    }

    private func showInAppNotification(for latestMessage: QueryDocumentSnapshot) {
        guard let senderName = latestMessage.data()["senderName"] as? String,
              let messageText = latestMessage.data()["text"] as? String else { return }

        let alertMessage = "\(senderName): \(messageText)"
        self.bannerMessage = alertMessage
        self.showNotificationBanner = true
    }

    private func mergeAndRemoveDuplicates(existingMatches: [Chat], newMatches: [Chat]) -> [Chat] {
        var combinedMatches = existingMatches

        for newMatch in newMatches {
            if let index = combinedMatches.firstIndex(where: { $0.id == newMatch.id }) {
                combinedMatches[index] = newMatch
            } else {
                combinedMatches.append(newMatch)
            }
        }

        return removeDuplicateChats(from: combinedMatches)
    }

    private func removeDuplicateChats(from chats: [Chat]) -> [Chat] {
        var uniqueChats = [Chat]()
        var seenPairs = Set<Set<String>>()

        for chat in chats {
            if let user1 = chat.user1, let user2 = chat.user2 {
                let userPair = Set([user1, user2])
                if !seenPairs.contains(userPair) {
                    uniqueChats.append(chat)
                    seenPairs.insert(userPair)
                }
            }
        }

        return uniqueChats
    }

    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

struct DMHomeView_Previews: PreviewProvider {
    static var previews: some View {
        DMHomeView(totalUnreadMessages: .constant(0))
            .environment(\.colorScheme, .dark)
    }
}
