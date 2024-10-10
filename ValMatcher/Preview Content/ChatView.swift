//
//  ChatView.swift
//  ValMatcher
//
//  Created by Daniel Han on 7/22/24.
//
import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    var matchID: String
    var recipientName: String
    @Binding var isInChatView: Bool
    @State private var messages: [Message] = []
    @State private var newMessage: String = ""
    @State private var currentUserID = Auth.auth().currentUser?.uid
    @State private var scrollToBottom: Bool = true
    @State private var messagesListener: ListenerRegistration?
    @State private var seenMessageIDs: Set<String> = []
    @State private var selectedImage: UIImage?
    @State private var isFullScreenImagePresented: IdentifiableImageURL?
    @State private var showAlert = false
    @State private var copiedText = ""
    @Binding var unreadMessageCount: Int

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack {
                        ForEach(messages) { message in
                            VStack {
                                if shouldShowDate(for: message) {
                                    Text("\(message.timestamp.dateValue(), formatter: dateOnlyFormatter)")
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                        .padding(.top, 10)
                                }

                                HStack {
                                    if message.isCurrentUser {
                                        Spacer()
                                        VStack(alignment: .trailing) {
                                            messageContent(for: message)
                                                .background(Color.blue)
                                                .cornerRadius(8)
                                                .foregroundColor(.white)
                                                .frame(maxWidth: 300, alignment: .trailing)
                                            Text("\(message.timestamp.dateValue(), formatter: timeFormatter)")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .padding(.top, 2)
                                        }
                                    } else {
                                        VStack(alignment: .leading) {
                                            messageContent(for: message)
                                                .background(Color.gray)
                                                .cornerRadius(8)
                                                .foregroundColor(.black)
                                                .frame(maxWidth: 300, alignment: .leading)
                                            Text("\(message.timestamp.dateValue(), formatter: timeFormatter)")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                                .padding(.top, 2)
                                        }
                                        Spacer()
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 5)
                                .id(message.id)
                            }
                        }
                    }
                }
                .onChange(of: messages) { _ in
                    if scrollToBottom {
                        DispatchQueue.main.async {
                            if let lastMessageID = messages.last?.id {
                                proxy.scrollTo(lastMessageID, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            HStack {
                TextField("Enter message", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(height: 40)

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .padding(10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
            }
            .padding()
        }
        .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom))
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(recipientName)
        .onAppear {
            print("DEBUG: Entering ChatView for matchID: \(matchID)")
            appState.isInChatView = true
            appState.currentChatID = matchID
            setupChatListener()
            markAllMessagesAsRead()
        }
        .onDisappear {
            print("DEBUG: Exiting ChatView for matchID: \(matchID)")
            appState.isInChatView = false
            appState.currentChatID = nil
            removeMessagesListener()
        }
    }

    private func messageContent(for message: Message) -> some View {
        Group {
            if let imageURL = message.imageURL {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 150)
                        .cornerRadius(8)
                        .onTapGesture {
                            isFullScreenImagePresented = IdentifiableImageURL(url: imageURL)
                        }
                } placeholder: {
                    ProgressView()
                        .frame(width: 150, height: 150)
                }
            } else {
                Text(message.content)
                    .padding()
                    .onTapGesture(count: 2) {
                        UIPasteboard.general.string = message.content
                        copiedText = message.content
                        showAlert = true
                    }
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = message.content
                            copiedText = message.content
                            showAlert = true
                        }) {
                            Text("Copy")
                            Image(systemName: "doc.on.doc")
                        }
                    }
            }
        }
    }

    private func sendMessage() {
        guard let currentUserID = Auth.auth().currentUser?.uid, !newMessage.isEmpty else { return }

        let messageToSend = newMessage
        DispatchQueue.main.async {
            self.newMessage = "" // Clear the input field immediately
        }

        let db = Firestore.firestore()
        let messageData: [String: Any] = [
            "senderID": currentUserID,
            "content": messageToSend,
            "timestamp": Timestamp(),
            "isRead": false
        ]

        db.collection("matches").document(matchID).collection("messages").addDocument(data: messageData) { error in
            if let error = error {
                print("Error sending message: \(error.localizedDescription)")
                // Optionally, restore the message if there's an error
                DispatchQueue.main.async {
                    self.newMessage = messageToSend
                }
                return
            }

            db.collection("matches").document(matchID).updateData(["lastMessageTimestamp": Timestamp()]) { error in
                if let error = error {
                    print("Error updating chat timestamp: \(error.localizedDescription)")
                }
            }
        }
    }

    private func setupChatListener() {
        let db = Firestore.firestore()
        messagesListener = db.collection("matches").document(matchID).collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener(includeMetadataChanges: false) { snapshot, error in
                if let error = error {
                    print("Error loading messages: \(error.localizedDescription)")
                    return
                }

                guard let snapshot = snapshot else {
                    print("No messages found")
                    return
                }

                var newMessages: [Message] = []
                var shouldScrollToBottom = false

                for diff in snapshot.documentChanges {
                    switch diff.type {
                    case .added:
                        if let message = try? diff.document.data(as: Message.self) {
                            if !self.seenMessageIDs.contains(message.id ?? "") {
                                self.seenMessageIDs.insert(message.id ?? "")
                                newMessages.append(message)
                                shouldScrollToBottom = true

                                if !message.isCurrentUser && self.isInChatView {
                                    self.markMessageAsRead(messageID: message.id ?? "")
                                }
                            }
                        }
                    case .modified:
                        if let message = try? diff.document.data(as: Message.self),
                           let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                            DispatchQueue.main.async {
                                self.messages[index] = message
                            }
                        }
                    case .removed:
                        if let index = self.messages.firstIndex(where: { $0.id == diff.document.documentID }) {
                            DispatchQueue.main.async {
                                self.messages.remove(at: index)
                            }
                        }
                    }
                }

                if !newMessages.isEmpty {
                    DispatchQueue.main.async {
                        self.messages.append(contentsOf: newMessages)
                        self.messages.sort { $0.timestamp.dateValue() < $1.timestamp.dateValue() }
                        scrollToBottom = true
                    }
                }
            }
    }

    private func removeMessagesListener() {
        messagesListener?.remove()
        messagesListener = nil
    }

    private func markMessageAsRead(messageID: String) {
        let db = Firestore.firestore()
        db.collection("matches").document(matchID).collection("messages").document(messageID).updateData(["isRead": true]) { error in
            if let error = error {
                print("Error marking message as read: \(error.localizedDescription)")
            }
        }
    }

    private func markAllMessagesAsRead() {
        guard let currentUserID = currentUserID else { return }
        let db = Firestore.firestore()
        let messagesRef = db.collection("matches").document(matchID).collection("messages")
        messagesRef.whereField("senderID", isNotEqualTo: currentUserID)
            .whereField("isRead", isEqualTo: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching unread messages: \(error.localizedDescription)")
                    return
                }

                let batch = db.batch()
                snapshot?.documents.forEach { document in
                    let messageRef = document.reference
                    batch.updateData(["isRead": true], forDocument: messageRef)
                }
                batch.commit { error in
                    if let error = error {
                        print("Error committing batch to mark messages as read: \(error.localizedDescription)")
                    }
                }
            }
    }

    private func shouldShowDate(for message: Message) -> Bool {
        guard let index = messages.firstIndex(of: message) else { return false }
        if index == 0 { return true }
        let previousMessage = messages[index - 1]
        let calendar = Calendar.current
        return !calendar.isDate(message.timestamp.dateValue(), inSameDayAs: previousMessage.timestamp.dateValue())
    }
}

// Date Formatters

let dateOnlyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .none
    return formatter
}()

let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
}()

// Identifiable Image URL for Image Presentation

struct IdentifiableImageURL: Identifiable {
    var id: String { url }
    var url: String
}
