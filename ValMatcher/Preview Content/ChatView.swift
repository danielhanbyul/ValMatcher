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

struct ChatView: View {
    var matchID: String
    var recipientName: String
    @State private var messages: [Message] = []
    @State private var newMessage: String = ""
    @State private var currentUserID = Auth.auth().currentUser?.uid
    @State private var scrollToBottom: Bool = true

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
                                            Text(message.content)
                                                .padding()
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
                                            Text(message.content)
                                                .padding()
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
        .onAppear(perform: loadMessages)
        .onChange(of: messages) { _ in
            scrollToBottom = true
        }
    }

    func loadMessages() {
        let db = Firestore.firestore()
        db.collection("matches").document(matchID).collection("messages")
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

                self.messages = documents.compactMap { document in
                    try? document.data(as: Message.self)
                }

                if self.messages.isEmpty {
                    print("Messages array is empty after fetching")
                } else {
                    print("Messages successfully loaded")
                }

                // Mark messages as read
                markMessagesAsRead()
            }
    }

    func sendMessage() {
        guard !newMessage.isEmpty else { return }

        let db = Firestore.firestore()
        let messageData: [String: Any] = [
            "senderID": currentUserID ?? "",
            "content": newMessage,
            "timestamp": FieldValue.serverTimestamp(),
            "isRead": false
        ]

        db.collection("matches").document(matchID).collection("messages").addDocument(data: messageData) { error in
            if let error = error {
                print("Error sending message: \(error.localizedDescription)")
            } else {
                print("Message sent successfully")
                self.newMessage = ""
                self.scrollToBottom = true
                updateHasUnreadMessages(for: matchID, hasUnread: true)
            }
        }
    }

    private func shouldShowDate(for message: Message) -> Bool {
        guard let index = messages.firstIndex(of: message) else { return false }
        if index == 0 {
            return true
        }
        let previousMessage = messages[index - 1]
        let calendar = Calendar.current
        return !calendar.isDate(message.timestamp.dateValue(), inSameDayAs: previousMessage.timestamp.dateValue())
    }

    private func markMessagesAsRead() {
        let db = Firestore.firestore()
        let batch = db.batch()
        
        messages.filter { !$0.isCurrentUser && !$0.isRead }.forEach { message in
            let messageRef = db.collection("matches").document(matchID).collection("messages").document(message.id ?? "")
            batch.updateData(["isRead": true], forDocument: messageRef)
        }
        
        batch.commit { error in
            if let error = error {
                print("Error marking messages as read: \(error.localizedDescription)")
            } else {
                updateHasUnreadMessages(for: matchID, hasUnread: false)
            }
        }
    }

    private func updateHasUnreadMessages(for matchID: String, hasUnread: Bool) {
        let db = Firestore.firestore()
        let matchRef = db.collection("matches").document(matchID)
        
        matchRef.updateData([
            "hasUnreadMessages": hasUnread
        ]) { error in
            if let error = error {
                print("Error updating unread messages status: \(error.localizedDescription)")
            } else {
                NotificationCenter.default.post(name: Notification.Name("UnreadMessagesUpdated"), object: nil)
                print("Updated hasUnreadMessages to \(hasUnread) for matchID \(matchID)")
            }
        }
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
