//
//  DMHomeView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/12/24.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import UserNotifications

struct DMHomeView: View {
    @State private var matches = [Chat]()
    @State private var currentUserID = Auth.auth().currentUser?.uid
    @State private var isEditing = false
    @State private var selectedMatches = Set<String>()
    @Binding var totalUnreadMessages: Int
    @State private var lastNotifiedMessageIDs = Set<String>() // Track notified message IDs

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Chat section
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
            loadMatches()
            listenForUnreadMessages()
            setupNotificationObserver()
        }
    }

    @ViewBuilder
    private func matchRow(match: Chat) -> some View {
        HStack {
            NavigationLink(destination: ChatView(matchID: match.id ?? "", recipientName: getRecipientName(for: match))) {
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

                    // Ensure correct display of red dot based on hasUnreadMessages
                    if match.hasUnreadMessages == true {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .padding(.trailing, 10)
                    }
                }
                .background(Color.black.opacity(0.7)) // Background color
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.vertical, 5)
                .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)
            }
        }
    }

    private func getRecipientName(for match: Chat) -> String {
        if let currentUserID = currentUserID {
            return currentUserID == match.user1 ? (match.user2Name ?? "Unknown User") : (match.user1Name ?? "Unknown User")
        }
        return "Unknown User"
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

    func loadMatches() {
        guard let currentUserID = currentUserID else {
            print("Error: currentUserID is nil")
            return
        }

        let db = Firestore.firestore()
        var loadedMatches = [Chat]()
        
        let group = DispatchGroup()

        group.enter()
        db.collection("matches")
            .whereField("user1", isEqualTo: currentUserID)
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error loading matches for user1: \(error.localizedDescription)")
                    group.leave()
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No documents for user1")
                    group.leave()
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
                loadedMatches.append(contentsOf: newMatches)
                group.leave()
            }

        group.enter()
        db.collection("matches")
            .whereField("user2", isEqualTo: currentUserID)
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error loading matches for user2: \(error.localizedDescription)")
                    group.leave()
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("No documents for user2")
                    group.leave()
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
                loadedMatches.append(contentsOf: moreMatches)
                group.leave()
            }

        group.notify(queue: .main) {
            fetchUserNames(for: loadedMatches) { updatedMatches in
                self.matches = Array(Set(updatedMatches)) // Ensure no duplicates
                self.updateUnreadMessagesCount()
                self.sortMatchesByMostRecentActivity()
                print("Loaded matches: \(self.matches)")
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

    private func updateUnreadMessagesCount() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        var count = 0
        var updatedMatches = self.matches  // Create a copy to modify

        let group = DispatchGroup()

        for match in updatedMatches {
            group.enter()
            let chatID = match.id ?? ""
            Firestore.firestore().collection("matches").document(chatID).collection("messages")
                .whereField("senderID", isNotEqualTo: currentUserID)
                .whereField("isRead", isEqualTo: false)
                .getDocuments { messageSnapshot, error in
                    if let error = error {
                        print("Error fetching messages: \(error)")
                        group.leave()
                        return
                    }
                    let unreadCount = messageSnapshot?.documents.count ?? 0
                    print("Unread count for \(chatID): \(unreadCount)")

                    if let matchIndex = updatedMatches.firstIndex(where: { $0.id == chatID }) {
                        let hasUnread = unreadCount > 0
                        updatedMatches[matchIndex].hasUnreadMessages = hasUnread  // Directly update the match
                        print("Updated match \(chatID) with hasUnreadMessages: \(hasUnread)")
                    }
                    count += unreadCount
                    group.leave()
                }
        }

        group.notify(queue: .main) {
            self.matches = updatedMatches  // Update state with modified array
            self.totalUnreadMessages = count
            print("Final matches state after update: \(self.matches)")
        }
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
        db.collection("matches")
            .whereField("user1", isEqualTo: currentUserID)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching matches: \(error)")
                    return
                }
                self.updateUnreadMessagesCount()
                if let snapshot = snapshot {
                    self.handleNotificationForNewMessages(snapshot: snapshot)
                }
            }
        
        db.collection("matches")
            .whereField("user2", isEqualTo: currentUserID)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching matches: \(error)")
                    return
                }
                self.updateUnreadMessagesCount()
                if let snapshot = snapshot {
                    self.handleNotificationForNewMessages(snapshot: snapshot)
                }
            }
    }

    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(forName: .newMessageNotification, object: nil, queue: .main) { notification in
            if let matchID = notification.userInfo?["matchID"] as? String,
               let message = notification.userInfo?["message"] as? String,
               let senderName = notification.userInfo?["senderName"] as? String {
                showNotificationBanner(message: "\(senderName): \(message)")
            }
        }
    }

    private func handleNotificationForNewMessages(snapshot: QuerySnapshot) {
        for diff in snapshot.documentChanges {
            if diff.type == .added || diff.type == .modified {
                let matchID = diff.document.documentID
                if !lastNotifiedMessageIDs.contains(matchID) {
                    lastNotifiedMessageIDs.insert(matchID)
                    if let match = self.matches.first(where: { $0.id == matchID }) {
                        fetchLastMessage(for: match)
                    }
                }
            }
        }
    }

    private func fetchLastMessage(for match: Chat) {
        guard let matchID = match.id else { return }

        let db = Firestore.firestore()
        db.collection("matches").document(matchID).collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching last message: \(error.localizedDescription)")
                    return
                }

                guard let document = snapshot?.documents.first else {
                    print("No messages found")
                    return
                }

                let message = document.data()["text"] as? String ?? ""
                let senderID = document.data()["senderID"] as? String ?? ""
                let senderName = senderID == match.user1 ? match.user1Name : match.user2Name

                if senderID != self.currentUserID {
                    NotificationCenter.default.post(name: .newMessageNotification, object: nil, userInfo: [
                        "matchID": matchID,
                        "message": message,
                        "senderName": senderName ?? "Unknown"
                    ])
                }

                // Update the match's timestamp and re-sort the list only if it's a new message
                if let matchIndex = self.matches.firstIndex(where: { $0.id == matchID }) {
                    if document.metadata.hasPendingWrites {
                        self.matches[matchIndex].timestamp = document.data()["timestamp"] as? Timestamp
                        self.sortMatchesByMostRecentActivity()
                    }
                }
            }
    }

    private func showNotificationBanner(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "New Message"
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func sortMatchesByMostRecentActivity() {
        self.matches.sort { $0.timestamp?.dateValue() ?? Date() > $1.timestamp?.dateValue() ?? Date() }
    }
}

extension Notification.Name {
    static let newMessageNotification = Notification.Name("newMessageNotification")
}
