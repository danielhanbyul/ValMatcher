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
    @State var matches: [Chat] = [] // Use @State for reactive updates
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
    @State private var isLoaded = false // To prevent multiple reloads


    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(matches) { match in
                            matchRow(match: match)
                                .background(isEditing && selectedMatches.contains(match.id ?? "") ? Color.gray.opacity(0.3) : Color.clear)
                                .onTapGesture {
                                    if isEditing {
                                        toggleSelection(for: match.id ?? "")
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
        }
        .navigationBarTitle("Messages", displayMode: .inline)
        .navigationBarItems(trailing: Button(action: { isEditing.toggle() }) {
            Text(isEditing ? "Done" : "Edit")
                .foregroundColor(.white)
        })
        .onAppear {
            setupListeners()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshChatList"))) { notification in
            if let chatID = notification.object as? String {
                print("Received notification to refresh chat: \(chatID)")
                if let index = matches.firstIndex(where: { $0.id == chatID }) {
                    withAnimation {
                        matches[index].hasUnreadMessages = false
                        print("Red dot should disappear for chatID: \(chatID)")
                    }
                }
            }
        }
        .background(
            NavigationLink(
                destination: selectedChatView(),
                isActive: Binding(
                    get: { selectedChat != nil },
                    set: { isActive in
                        if !isActive {
                            print("NavigationLink is trying to reset selectedChat")
                            selectedChat = nil
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

    private func toggleSelection(for matchID: String) {
        if selectedMatches.contains(matchID) {
            selectedMatches.remove(matchID)
        } else {
            selectedMatches.insert(matchID)
        }
    }
    
    

    // Deletion of selected matches
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
                print("Matches deleted successfully")
                selectedMatches.removeAll()
                loadMatches()  // Reload to reflect changes
            }
        }
    }

    @ViewBuilder
    private func selectedChatView() -> some View {
        if let chat = selectedChat {
            ChatView(matchID: chat.id ?? "", recipientName: getRecipientName(for: chat))
                .onAppear {
                    print("ChatView appeared with selectedChat: \(selectedChat?.id ?? "nil")")
                    
                    // Check if the selected chat has unread messages and blend the red dot
                    if let index = matches.firstIndex(where: { $0.id == chat.id }), matches[index].hasUnreadMessages == true {
                        markMessagesAsRead(for: chat) // Mark the messages as read
                        blendRedDot(for: index) // Blend the red dot specifically for this chat
                    }
                }
                .onDisappear {
                    print("ChatView disappeared, selectedChat: \(selectedChat?.id ?? "nil")")
                    NotificationCenter.default.post(name: Notification.Name("RefreshChatList"), object: chat.id)
                }
        } else {
            EmptyView()
        }
    }




    @ViewBuilder
    private func matchRow(match: Chat) -> some View {
        HStack {
            Button(action: {
                selectedChat = match
                
                // Check if the chat has unread messages and mark it as read
                if match.hasUnreadMessages ?? false {
                    if let index = matches.firstIndex(where: { $0.id == match.id }) {
                        withAnimation {
                            // Mark the message as read and blend the red dot
                            matches[index].hasUnreadMessages = false
                            blendRedDot(for: index) // Blend red dot specifically for this chat
                        }
                    }
                }
            }) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(getRecipientName(for: match))
                            .font(.custom("AvenirNext-Bold", size: 18))
                            .foregroundColor(.white)
                    }
                    .padding()
                    Spacer()

                    // Display the red dot if there are unread messages
                    if match.hasUnreadMessages ?? false {
                        Circle()
                            .fill(blendColor) // Blend color will be animated
                            .frame(width: 10, height: 10)
                            .padding(.trailing, 10)
                            .transition(.opacity) // Fades out smoothly
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


    private func blendRedDot(for index: Int) {
        withAnimation(.easeInOut(duration: 1.0)) {
            // Set blendColor to black to blend the red dot with the background
            blendColor = Color.black.opacity(0.7) // Background color of the row
        }
    }


    // Function to restore the red dot
    private func restoreRedDot() {
        withAnimation(.easeInOut(duration: 1.0)) {
            blendColor = Color.red // Restore the red dot color
        }
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
                    DispatchQueue.main.async {
                        if let index = self.matches.firstIndex(where: { $0.id == chat.id }) {
                            self.matches[index].hasUnreadMessages = false
                        }
                        NotificationCenter.default.post(name: Notification.Name("RefreshChatList"), object: matchID)
                    }
                }
            }
        }
    }

    // Helper function to get the recipient's name
    private func getRecipientName(for match: Chat?) -> String {
        guard let match = match, let currentUserID = currentUserID else { return "Unknown User" }
        return currentUserID == match.user1 ? (match.user2Name ?? "Unknown User") : (match.user1Name ?? "Unknown User")
    }

    // Load the matches and set up listeners
    func setupListeners() {
        loadMatches()
    }

    func loadMatches() {
        // Check if matches are already loaded
        guard !isLoaded, let currentUserID = currentUserID else {
            return
        }

        let db = Firestore.firestore()
        let queries = [
            db.collection("matches").whereField("user1", isEqualTo: currentUserID),
            db.collection("matches").whereField("user2", isEqualTo: currentUserID)
        ]

        for query in queries {
            query.order(by: "timestamp", descending: true).getDocuments { snapshot, error in
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
                                    self.matches = updatedMatches
                                    self.updateUnreadMessagesCount(from: self.matches)
                                    print("Loaded matches: \(self.matches)")
                                    // Mark as loaded to prevent reloading
                                    self.isLoaded = true
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


    // Helper function to update unread message count
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

    // Helper function to fetch user names
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

    // Helper function to update the unread messages count
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
}
