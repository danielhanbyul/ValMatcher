//
//  ChatView.swift
//  ValMatcher
//
//  Created by Daniel Han on 7/22/24.
//
import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth

struct ChatView: View {
    var matchID: String
    var recipientName: String
    @State private var messages: [Message] = []
    @State private var newMessage: String = ""
    @State private var currentUserID = Auth.auth().currentUser?.uid
    @State private var scrollToBottom: Bool = true
    @State private var messagesListener: ListenerRegistration?
    @State private var selectedImage: UIImage?
    @State private var isFullScreenImagePresented: IdentifiableImageURL?
    @State private var showAlert = false
    @State private var copiedText = ""
    @State private var unreadMessagesCount: Int = 0


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
                            proxy.scrollTo(messages.last?.id, anchor: .bottom)
                            scrollToBottom = false // Reset after scrolling
                        }
                    }
                }
            }

            HStack {
                TextField("Enter message", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .frame(height: 40)

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .padding()
            }
            .padding()
        }
        .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom))
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(recipientName)
        .onAppear {
                    // Notify that we've entered ChatView
                    NotificationCenter.default.post(name: Notification.Name("EnteredChatView"), object: nil)
                    setupChatListener()
                }
                .onDisappear {
                    // Notify that we've exited ChatView
                    NotificationCenter.default.post(name: Notification.Name("ExitedChatView"), object: nil)
                    markMessagesAsRead()
                    removeMessagesListener()
                    NotificationCenter.default.post(name: Notification.Name("RefreshChatList"), object: matchID)
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

        let db = Firestore.firestore()
        let messageData: [String: Any] = [
            "senderID": currentUserID,
            "content": newMessage,
            "timestamp": Timestamp(),
            "isRead": false
        ]

        // Add the message to Firestore
        db.collection("matches").document(matchID).collection("messages").addDocument(data: messageData) { error in
            if let error = error {
                print("Error sending message: \(error.localizedDescription)")
                return
            }

            // Update the chat timestamp to the most recent
            db.collection("matches").document(matchID).updateData(["lastMessageTimestamp": Timestamp()]) { error in
                if let error = error {
                    print("Error updating chat timestamp: \(error.localizedDescription)")
                } else {
                    self.newMessage = "" // Clear the input field after sending
                }
            }
        }
    }

    private func setupChatListener() {
        guard messagesListener == nil else { return }  // Prevent setting up multiple listeners

        let db = Firestore.firestore()
        messagesListener = db.collection("matches").document(matchID).collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error loading messages: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("No messages found")
                    return
                }

                // Append new messages without resetting the array
                let newMessages = documents.compactMap { document in
                    try? document.data(as: Message.self)
                }

                // Filter to append only the new messages
                let filteredMessages = newMessages.filter { newMessage in
                    !self.messages.contains(where: { $0.id == newMessage.id })
                }

                if !filteredMessages.isEmpty {
                    self.messages.append(contentsOf: filteredMessages)

                    // Scroll to the bottom when new messages arrive
                    DispatchQueue.main.async {
                        scrollToBottom = true
                    }
                }
            }
    }


    private func removeMessagesListener() {
        messagesListener?.remove()
        messagesListener = nil
    }

    private func markMessagesAsRead() {
        guard let currentUserID = currentUserID else { return }
        let db = Firestore.firestore()
        let batch = db.batch()

        let unreadMessages = messages.filter { !$0.isCurrentUser && !$0.isRead }
        if unreadMessages.isEmpty { return }  // No unread messages, so return early

        unreadMessages.forEach { message in
            let messageRef = db.collection("matches").document(matchID).collection("messages").document(message.id ?? "")
            batch.updateData(["isRead": true], forDocument: messageRef)
        }

        batch.commit { error in
            if let error = error {
                print("Error marking messages as read: \(error.localizedDescription)")
            } else {
                self.unreadMessagesCount = 0
                NotificationCenter.default.post(name: Notification.Name("RefreshChatList"), object: matchID)
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

struct IdentifiableImageURL: Identifiable {
    var id: String { url }
    var url: String
}
