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

struct DMHomeView: View {
    @State private var matches = [Chat]()
    @State private var currentUserID = Auth.auth().currentUser?.uid
    @State private var isEditing = false
    @State private var selectedMatches = Set<String>()
    @Binding var totalUnreadMessages: Int
    @State private var shouldSortChats = true
    @State private var receivedNewMessage = false
    @State private var selectedChat: Chat? // The chat that the user is trying to open
    @State private var showNotificationBanner = false
    @State private var bannerMessage = ""
    @State private var previousSelectedChatID: String? // Keep track of the chat to prevent reset
    @State private var blendColor = Color.red // The color for the red dot

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

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
        }
        .navigationBarTitle("Messages", displayMode: .inline)
        .navigationBarItems(trailing: Button(action: { isEditing.toggle() }) {
            Text(isEditing ? "Done" : "Edit")
                .foregroundColor(.white)
        })
        .onAppear {
            setupListeners()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            setupListeners()
        }
        .background(
            NavigationLink(
                destination: selectedChatView(),
                isActive: Binding(
                    get: { selectedChat != nil },
                    set: { isActive in
                        if !isActive {
                            selectedChat = nil
                            print("NavigationLink is trying to reset selectedChat")
                        }
                    }
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
    private func selectedChatView() -> some View {
        if let chat = selectedChat {
            ChatView(matchID: chat.id ?? "", recipientName: getRecipientName(for: chat))
                .onAppear {
                    print("ChatView appeared with selectedChat: \(selectedChat?.id ?? "nil")")
                    markMessagesAsRead(for: chat)
                    blendRedDot()
                }
                .onDisappear {
                    print("ChatView disappeared, selectedChat: \(selectedChat?.id ?? "nil")")
                }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func matchRow(match: Chat) -> some View {
        Button(action: {
            selectedChat = match
            if let currentUserID = currentUserID {
                reduceUnreadMessageCount(for: match, currentUserID: currentUserID)
            }
            if let index = matches.firstIndex(where: { $0.id == match.id }) {
                matches[index].hasUnreadMessages = false
            }
        }) {
            HStack {
                VStack(alignment: .leading) {
                    Text(getRecipientName(for: match))
                        .font(.custom("AvenirNext-Bold", size: 18))
                        .foregroundColor(.white)
                    Text(lastMessageTimestamp(match: match))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                Spacer()

                if match.hasUnreadMessages == true {
                    Circle()
                        .fill(blendColor)
                        .frame(width: 10, height: 10)
                        .padding(.trailing, 10)
                        .transition(.opacity)
                }
            }
            .background(Color.black.opacity(0.7))
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.vertical, 5)
            .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)
        }
    }

    private func lastMessageTimestamp(match: Chat) -> String {
        if let timestamp = match.timestamp {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return formatter.localizedString(for: timestamp.dateValue(), relativeTo: Date())
        } else {
            return "No messages"
        }
    }

    // This function blends the red dot with the background color over time
    private func blendRedDot() {
        withAnimation(.easeInOut(duration: 1.0)) {
            blendColor = Color.black.opacity(0.7) // Blend with the background color
        }
    }

    // This function restores the red dot when a new message arrives
    private func restoreRedDot() {
        withAnimation(.easeInOut(duration: 1.0)) {
            blendColor = Color.red // Restore the red dot color
        }
    }

    private func reduceUnreadMessageCount(for match: Chat, currentUserID: String) {
        guard let matchID = match.id else { return }

        let db = Firestore.firestore()
        let messagesRef = db.collection("matches").document(matchID).collection("messages")

        messagesRef.whereField("senderID", isNotEqualTo: currentUserID)
            .whereField("isRead", isEqualTo: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching unread messages: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    return
                }

                let batch = db.batch()
                documents.forEach { document in
                    batch.updateData(["isRead": true], forDocument: document.reference)
                }

                batch.commit { error in
                    if let error = error {
                        print("Error marking messages as read: \(error.localizedDescription)")
                    } else {
                        if let index = self.matches.firstIndex(where: { $0.id == match.id }) {
                            self.matches[index].hasUnreadMessages = false
                        }
                    }
                }
            }
    }

    // The missing markMessagesAsRead function
    private func markMessagesAsRead(for chat: Chat) {
        guard let matchID = chat.id, let currentUserID = currentUserID else { return }

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
                } else {
                    DispatchQueue.main.async {
                        if let index = self.matches.firstIndex(where: { $0.id == chat.id }) {
                            self.matches[index].hasUnreadMessages = false
                        }
                        NotificationCenter.default.post(name: Notification.Name("RefreshChatList"), object: nil)
                    }
                }
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

    func setupListeners() {
        let currentChatID = selectedChat?.id
        loadMatches()

        if let currentChatID = currentChatID {
            self.selectedChat = matches.first(where: { $0.id == currentChatID })
            print("Restored selectedChat after listener update: \(selectedChat?.id ?? "nil")")
        }
    }

    func loadMatches() {
        guard let currentUserID = currentUserID else {
            print("Error: currentUserID is nil")
            return
        }

        let db = Firestore.firestore()

        let queries = [
            db.collection("matches").whereField("user1", isEqualTo: currentUserID),
            db.collection("matches").whereField("user2", isEqualTo: currentUserID)
        ]

        for query in queries {
            query.order(by: "timestamp", descending: true).addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error loading matches: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("No documents found")
                    return
                }

                var newMatches = [Chat]()

                for document in documents {
                    do {
                        var match = try document.data(as: Chat.self)

                        self.updateUnreadMessageCount(for: match, currentUserID: currentUserID) { updatedMatch in
                            newMatches.append(updatedMatch)

                            if newMatches.count == documents.count {
                                fetchUserNames(for: newMatches) { updatedMatches in
                                    self.matches = self.mergeAndRemoveDuplicates(existingMatches: self.matches, newMatches: updatedMatches)
                                    self.updateUnreadMessagesCount(from: self.matches)
                                    print("Loaded matches: \(self.matches)")
                                }
                            }
                        }
                    } catch {
                        print("Error decoding match: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func updateUnreadMessageCount(for match: Chat, currentUserID: String, completion: @escaping (Chat) -> Void) {
        let db = Firestore.firestore()

        guard let matchID = match.id else { return }

        var matchCopy = match

        db.collection("matches").document(matchID).collection("messages")
            .whereField("senderID", isNotEqualTo: currentUserID)
            .whereField("isRead", isEqualTo: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching unread messages: \(error.localizedDescription)")
                    return
                }

                let unreadCount = snapshot?.documents.count ?? 0

                if matchCopy.unreadMessages == nil {
                    matchCopy.unreadMessages = [:]
                }
                matchCopy.unreadMessages?[currentUserID] = unreadCount
                matchCopy.hasUnreadMessages = unreadCount > 0

                completion(matchCopy)
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
        }
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
}
