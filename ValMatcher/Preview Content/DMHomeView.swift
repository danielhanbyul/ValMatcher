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
import UserNotifications

import SwiftUI
import Firebase
import Combine

class FirebaseCombineManager: ObservableObject {
    @Published var unreadMessagesCount = 0
    private var cancellables: Set<AnyCancellable> = []
    
    // Method to listen for unread messages
    func startListening(currentUserID: String) {
        let db = Firestore.firestore()
        
        // Create a listener for Firestore snapshots and wrap it in a Combine publisher
        let listener = db.collection("matches")
            .whereField("user1", isEqualTo: currentUserID)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching matches: \(error)")
                    return
                }
                self.handleSnapshot(snapshot, currentUserID: currentUserID)
            }
        
        // Keep a reference to the listener to manage its lifecycle
        let _ = listener  // In a real implementation, you might store this reference if needed
    }
    
    // Handle snapshot changes
    private func handleSnapshot(_ snapshot: QuerySnapshot?, currentUserID: String) {
        var totalUnread = 0
        let group = DispatchGroup()

        snapshot?.documents.forEach { document in
            group.enter()
            let matchID = document.documentID
            Firestore.firestore().collection("matches").document(matchID).collection("messages")
                .whereField("senderID", isNotEqualTo: currentUserID)
                .whereField("isRead", isEqualTo: false)
                .getDocuments { messageSnapshot, error in
                    if let error = error {
                        print("Error fetching messages: \(error)")
                        group.leave()
                        return
                    }
                    totalUnread += messageSnapshot?.documents.count ?? 0
                    group.leave()
                }
        }

        group.notify(queue: .main) {
            self.unreadMessagesCount = totalUnread
        }
    }
    
    // To stop the listener and clear Combine's cancellables
    func stopListening() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
}

struct DMHomeView: View {
    @State private var matches = [Chat]()
    @State private var currentUserID = Auth.auth().currentUser?.uid
    @State private var isEditing = false
    @State private var selectedMatches = Set<String>()
    @Binding var totalUnreadMessages: Int
    
    @State private var unreadMessagesCount: Int = 0

    var hasUnreadMessages: Bool {
        return unreadMessagesCount > 0
    }

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
            loadMatches()
            listenForUnreadMessages()
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
                    print("Loaded matches for user2: \(self.matches)")
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
                .whereField("senderID", isNotEqualTo: currentUserID)
                .whereField("isRead", isEqualTo: false)
                .getDocuments { messageSnapshot, error in
                    if let error = error {
                        print("Error fetching messages: \(error)")
                        group.leave()
                        return
                    }

                    let unreadCount = messageSnapshot?.documents.count ?? 0

                    if unreadCount > 0 {
                        updatedMatches[index].hasUnreadMessages = true
                    } else {
                        updatedMatches[index].hasUnreadMessages = false
                    }

                    count += unreadCount
                    group.leave()
                }
        }

        group.notify(queue: .main) {
            self.totalUnreadMessages = count
            self.matches = updatedMatches
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

        // Set up listener for new messages
        db.collection("matches")
            .whereField("user1", isEqualTo: currentUserID)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching matches: \(error)")
                    return
                }

                self.updateUnreadMessagesCount(from: self.matches)

                // Notify user of new messages if a new message is added
                snapshot?.documentChanges.forEach { change in
                    if change.type == .added {
                        if let match = try? change.document.data(as: Chat.self) {
                            db.collection("matches").document(match.id!).collection("messages")
                                .whereField("isRead", isEqualTo: false)
                                .whereField("senderID", isNotEqualTo: currentUserID)
                                .addSnapshotListener { messageSnapshot, error in
                                    if let error = error {
                                        print("Error fetching new messages: \(error)")
                                        return
                                    }

                                    if let messages = messageSnapshot?.documents, let lastMessage = messages.last {
                                        if let senderName = match.user1 == currentUserID ? match.user2Name : match.user1Name,
                                           let messageText = lastMessage.data()["text"] as? String {
                                            self.notifyUserOfNewMessages(senderName: senderName, message: messageText)
                                        }
                                    }
                                    self.updateUnreadMessagesCount(from: self.matches)
                                }
                        }
                    }
                }
            }
    }


    private func notifyUserOfNewMessages(senderName: String, message: String) {
        // Trigger an in-app notification
        let alertMessage = "\(senderName): \(message)"
        showNotification(title: "New Message", body: alertMessage)

        // Also trigger a system notification
        let content = UNMutableNotificationContent()
        content.title = "New Message"
        content.body = alertMessage
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
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
