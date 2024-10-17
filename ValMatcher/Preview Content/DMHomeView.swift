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

struct DMHomeView: View {
    @EnvironmentObject var appState: AppState  // Access the shared app state
    @State var matches: [Chat] = []
    @State private var currentUserID = Auth.auth().currentUser?.uid
    @State private var isEditing = false
    @State private var selectedMatches = Set<String>()
    @Binding var totalUnreadMessages: Int
    @State private var receivedNewMessage = false
    @State private var showNotificationBanner = false
    @State private var bannerMessage = ""
    @State private var previousSelectedChatID: String?
    @State private var blendColor = Color.red
    @State private var isLoaded = false
    @State private var userNamesCache: [String: String] = [:] // Cache for usernames

    // State variables for navigation
    @State private var selectedMatch: Chat?
    @State private var isChatActive = false
    @State private var isInChatView: Bool = false
    @State private var currentChatID: String? = nil

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.02, green: 0.18, blue: 0.15),
                    Color(red: 0.21, green: 0.29, blue: 0.40)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(matches) { match in
                            matchRow(match: match)
                                .background(
                                    isEditing && selectedMatches.contains(match.id ?? "") ?
                                    Color.gray.opacity(0.3) : Color.clear
                                )
                                .onTapGesture {
                                    if let matchID = match.id {
                                        // Clean up listeners and enter ChatView
                                        enterChatView(with: matchID)
                                        
                                        // Set selected match and trigger navigation
                                        self.selectedMatch = match
                                        self.isChatActive = true
                                    }
                                }
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

            // NavigationLink to trigger ChatView
            NavigationLink(
                destination: ChatView(
                    matchID: selectedMatch?.id ?? "",
                    recipientName: getRecipientName(for: selectedMatch),
                    isInChatView: $isInChatView,
                    unreadMessageCount: $totalUnreadMessages
                )
                .onAppear {
                    print("DEBUG: Entered ChatView for matchID: \(selectedMatch?.id ?? "")")
                    appState.isInChatView = true
                    isInChatView = true
                }
                .onDisappear {
                    print("DEBUG: Preparing to exit ChatView for matchID: \(selectedMatch?.id ?? "")")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if !isInChatView {
                            print("DEBUG: Exiting and cleaning up ChatView")
                            appState.removeChatListener(for: selectedMatch?.id ?? "")
                            isInChatView = false
                        } else {
                            print("DEBUG: Still in chat, not removing listener")
                        }
                    }
                    // Update unread messages count after returning to DMHomeView
                    refreshUnreadMessageCount()
                },
                isActive: $isChatActive
            ) {
                EmptyView()
            }
        }
        .navigationBarTitle("Messages", displayMode: .inline)
        .navigationBarItems(trailing: Button(action: { isEditing.toggle() }) {
            Text(isEditing ? "Done" : "Edit")
                .foregroundColor(.white)
        })
        .onAppear {
            print("DEBUG: onAppear - Entering DMHomeView")
            if !isLoaded {
                loadMatches()
            }
            setupListeners()

            // Debugging unread message count updates
            if !isInChatView {
                print("DEBUG: Refreshing unreadMessageCount as not in ChatView")
                refreshUnreadMessageCount()
            }
        }

        .onDisappear {
            print("DEBUG: onDisappear - Leaving DMHomeView")
            isInChatView = false
        }


        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshChatList"))) { notification in
            if let chatID = notification.object as? String {
                if let index = matches.firstIndex(where: { $0.id == chatID }), let currentUserID = self.currentUserID {
                    // Update the unread message count for the specific match
                    self.updateUnreadMessageCount(for: matches[index], currentUserID: currentUserID) { updatedMatch in
                        self.matches[index] = updatedMatch
                    }
                }
            }
        }
        .alert(isPresented: $showNotificationBanner) {
            Alert(title: Text("New Message"), message: Text(bannerMessage), dismissButton: .default(Text("OK")))
        }
    }

    // Function to enter ChatView and clean up listeners
    func enterChatView(with matchID: String) {
        // Clean up any existing listeners
        appState.removeChatListener(for: matchID)
        
        // Set up new listener and navigation state
        self.currentChatID = matchID
        self.isChatActive = true
        self.isInChatView = true
        appState.isInChatView = true
        appState.currentChatID = matchID
    }

    // Function to refresh unread message count after navigating back
    func refreshUnreadMessageCount() {
        let db = Firestore.firestore()
        guard let currentUserID = currentUserID else { return }

        var totalUnread = 0
        let matchesRef = db.collection("matches")
        
        matchesRef.whereField("user1", isEqualTo: currentUserID).getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching matches: \(error.localizedDescription)")
                return
            }

            for document in snapshot?.documents ?? [] {
                let matchID = document.documentID
                db.collection("matches").document(matchID).collection("messages")
                    .whereField("isRead", isEqualTo: false)
                    .whereField("senderID", isNotEqualTo: currentUserID)
                    .getDocuments { messageSnapshot, error in
                        if let messageError = error {
                            print("Error fetching unread messages: \(messageError.localizedDescription)")
                            return
                        }
                        totalUnread += messageSnapshot?.documents.count ?? 0

                        DispatchQueue.main.async {
                            totalUnreadMessages = totalUnread
                            print("DEBUG: Unread messages refreshed: \(totalUnread)")
                        }
                    }
            }
        }
    }

    // Other existing functions such as toggleSelection, deleteSelectedMatches, markMessagesAsRead...

    private func toggleSelection(for matchID: String) {
        if selectedMatches.contains(matchID) {
            selectedMatches.remove(matchID)
        } else {
            selectedMatches.insert(matchID)
        }
    }

    func deleteSelectedMatches() {
        let db = Firestore.firestore()
        let batch = db.batch()

        for matchID in selectedMatches {
            if let index = matches.firstIndex(where: { $0.id == matchID }) {
                matches.remove(at: index)
            }
            let matchRef = db.collection("matches").document(matchID)
            batch.deleteDocument(matchRef)
        }

        batch.commit { error in
            if let error = error {
                print("Error deleting matches: \(error.localizedDescription)")
            } else {
                selectedMatches.removeAll()
                loadMatches()
            }
        }
    }

    @ViewBuilder
    private func matchRow(match: Chat) -> some View {
        HStack {
            if isEditing {
                Button(action: {
                    toggleSelection(for: match.id ?? "")
                }) {
                    Image(systemName: selectedMatches.contains(match.id ?? "") ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(.white)
                }
                .padding(.leading)
            }

            VStack(alignment: .leading) {
                Text(getRecipientName(for: match))
                    .font(.custom("AvenirNext-Bold", size: 18))
                    .foregroundColor(.white)
            }
            .padding()
            Spacer()

            if (match.hasUnreadMessages ?? false) && !(isInChatView && match.id == currentChatID) {
                Circle()
                    .fill(blendColor)
                    .frame(width: 10, height: 10)
                    .padding(.trailing, 10)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditing {
                toggleSelection(for: match.id ?? "")
            } else {
                self.selectedMatch = match
                if let matchID = match.id {
                    self.currentChatID = matchID
                    self.isInChatView = true
                    self.isChatActive = true
                    if let index = matches.firstIndex(where: { $0.id == matchID }), matches[index].hasUnreadMessages == true {
                        markMessagesAsRead(for: match)
                        blendRedDot(for: index)
                    }
                }
            }
        }
        .background(
            isEditing && selectedMatches.contains(match.id ?? "") ?
            Color.gray.opacity(0.3) : Color.black.opacity(0.7)
        )
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.vertical, 5)
        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)
    }

    private func blendRedDot(for index: Int) {
        blendColor = Color.black.opacity(0.7)
    }

    private func restoreRedDot() {
        blendColor = Color.red
    }

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
                    if let index = self.matches.firstIndex(where: { $0.id == chat.id }) {
                        self.matches[index].hasUnreadMessages = false
                    }
                    NotificationCenter.default.post(name: Notification.Name("RefreshChatList"), object: matchID)
                }
            }
        }
    }

    private func getRecipientName(for match: Chat?) -> String {
        guard let match = match, let currentUserID = currentUserID else { return "Unknown User" }
        let userID = currentUserID == match.user1 ? match.user2 : match.user1

        if let cachedName = getUsernameFromCache(userID: userID ?? "") {
            return cachedName
        }

        if let userID = userID {
            fetchAndCacheUserName(for: userID) { _ in }
        }

        return "Unknown User"
    }

    func setupListeners() {
        setupRealTimeListener()
    }

    func loadMatches() {
        guard let currentUserID = currentUserID else { return }

        let db = Firestore.firestore()
        let queries = [
            db.collection("matches").whereField("user1", isEqualTo: currentUserID),
            db.collection("matches").whereField("user2", isEqualTo: currentUserID)
        ]

        for query in queries {
            query.getDocuments { snapshot, error in
                if let error = error {
                    print("Error loading matches: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                var newMatches = [Chat]()
                let group = DispatchGroup()

                for document in documents {
                    do {
                        var match = try document.data(as: Chat.self)
                        group.enter()
                        self.updateUnreadMessageCount(for: match, currentUserID: currentUserID) { updatedMatch in
                            newMatches.append(updatedMatch)
                            group.leave()
                        }
                    } catch {
                        print("Error decoding match: \(error.localizedDescription)")
                    }
                }

                group.notify(queue: .main) {
                    self.fetchUserNames(for: newMatches) { updatedMatches in
                        self.matches = updatedMatches.sorted {
                            ($0.lastMessageTimestamp?.dateValue() ?? Date.distantPast) > ($1.lastMessageTimestamp?.dateValue() ?? Date.distantPast)
                        }
                        self.updateUnreadMessagesCount(from: self.matches)
                        self.isLoaded = true
                    }
                }
            }
        }
    }

    func setupRealTimeListener() {
        guard let currentUserID = currentUserID else { return }
        let db = Firestore.firestore()

        let queries = [
            db.collection("matches").whereField("user1", isEqualTo: currentUserID),
            db.collection("matches").whereField("user2", isEqualTo: currentUserID)
        ]

        for query in queries {
            query.addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error in real-time listener: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                let group = DispatchGroup()

                for document in documents {
                    do {
                        var match = try document.data(as: Chat.self)
                        group.enter()
                        self.updateUnreadMessageCount(for: match, currentUserID: currentUserID) { updatedMatch in
                            if self.isInChatView && self.currentChatID == updatedMatch.id {
                                print("DEBUG: Skipping update for current chat matchID: \(updatedMatch.id ?? "")")
                            } else {
                                if let index = self.matches.firstIndex(where: { $0.id == updatedMatch.id }) {
                                    self.matches[index] = updatedMatch
                                } else {
                                    self.matches.append(updatedMatch)
                                }
                            }
                            group.leave()
                        }
                    } catch {
                        print("Error decoding match: \(error.localizedDescription)")
                    }
                }

                group.notify(queue: .main) {
                    self.matches = self.matches.sorted {
                        ($0.lastMessageTimestamp?.dateValue() ?? Date.distantPast) > ($1.lastMessageTimestamp?.dateValue() ?? Date.distantPast)
                    }
                }
            }
        }
    }

    private func updateUnreadMessageCount(for match: Chat, currentUserID: String, completion: @escaping (Chat) -> Void) {
        let db = Firestore.firestore()
        guard let matchID = match.id else { return }

        var matchCopy = match

        if isInChatView && matchID == currentChatID {
            matchCopy.hasUnreadMessages = false
            completion(matchCopy)
            return
        }

        db.collection("matches").document(matchID).collection("messages")
            .whereField("senderID", isNotEqualTo: currentUserID)
            .whereField("isRead", isEqualTo: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching unread messages: \(error.localizedDescription)")
                    completion(matchCopy)
                    return
                }

                let unreadCount = snapshot?.documents.count ?? 0
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
                        fetchAndCacheUserName(for: user2) { name in
                            updatedMatches[i].user2Name = name
                            dispatchGroup.leave()
                        }
                    }
                } else {
                    if let user1 = updatedMatches[i].user1 {
                        fetchAndCacheUserName(for: user1) { name in
                            updatedMatches[i].user1Name = name
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

    private func fetchAndCacheUserName(for userID: String, completion: @escaping (String) -> Void) {
        if let cachedName = getUsernameFromCache(userID: userID) {
            completion(cachedName)
            return
        }

        Firestore.firestore().collection("users").document(userID).getDocument { document, error in
            if let document = document, document.exists {
                let name = document.data()?["name"] as? String ?? "Unknown User"
                self.userNamesCache[userID] = name
                saveUsernameToCache(userID: userID, username: name)
                completion(name)
            } else {
                self.userNamesCache[userID] = "Unknown User"
                saveUsernameToCache(userID: userID, username: "Unknown User")
                completion("Unknown User")
            }
        }
    }

    private func saveUsernameToCache(userID: String, username: String) {
        var cachedUsernames = UserDefaults.standard.dictionary(forKey: "cachedUsernames") as? [String: String] ?? [:]
        cachedUsernames[userID] = username
        UserDefaults.standard.setValue(cachedUsernames, forKey: "cachedUsernames")
    }

    private func getUsernameFromCache(userID: String) -> String? {
        let cachedUsernames = UserDefaults.standard.dictionary(forKey: "cachedUsernames") as? [String: String]
        return cachedUsernames?[userID]
    }

    private func updateUnreadMessagesCount(from matches: [Chat]) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        var count = 0
        let group = DispatchGroup()

        var updatedMatches = matches

        for (index, match) in updatedMatches.enumerated() {
            guard let matchID = match.id else { continue }
            group.enter()
            if isInChatView && matchID == currentChatID {
                updatedMatches[index].hasUnreadMessages = false
                group.leave()
                continue
            }

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
                        updatedMatches[index].lastMessageTimestamp = latestMessage.data()["timestamp"] as? Timestamp
                    }

                    count += unreadCount
                    group.leave()
                }
        }

        group.notify(queue: .main) {
            self.totalUnreadMessages = count
            self.matches = updatedMatches.sorted {
                ($0.lastMessageTimestamp?.dateValue() ?? Date.distantPast) > ($1.lastMessageTimestamp?.dateValue() ?? Date.distantPast)
            }
        }
    }
}
