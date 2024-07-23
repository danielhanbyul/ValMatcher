//
//  ChatView.swift
//  ValMatcher
//
//  Created by Daniel Han on 7/22/24.
//

import SwiftUI
import Firebase

struct ChatView: View {
    var matchID: String
    @State private var messages: [Message] = []
    @State private var newMessage: String = ""
    @State private var currentUserID = Auth.auth().currentUser?.uid

    var body: some View {
        VStack {
            ScrollView {
                ForEach(messages) { message in
                    HStack {
                        if message.isCurrentUser {
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(message.content)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(8)
                                    .foregroundColor(.white)
                                Text("\(message.timestamp.dateValue(), formatter: dateFormatter)")
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
                                Text("\(message.timestamp.dateValue(), formatter: dateFormatter)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.top, 2)
                            }
                            Spacer()
                        }
                    }
                    .padding()
                }
            }

            HStack {
                TextField("Enter message", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

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
        .onAppear(perform: loadMessages)
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
                    print("No messages")
                    return
                }

                self.messages = documents.compactMap { document in
                    try? document.data(as: Message.self)
                }
            }
    }

    func sendMessage() {
        guard !newMessage.isEmpty else { return }

        let db = Firestore.firestore()
        let messageData: [String: Any] = [
            "senderID": currentUserID ?? "",
            "content": newMessage,
            "timestamp": FieldValue.serverTimestamp()
        ]

        db.collection("matches").document(matchID).collection("messages").addDocument(data: messageData) { error in
            if let error = error {
                print("Error sending message: \(error.localizedDescription)")
            } else {
                print("Message sent successfully")
                self.newMessage = ""
            }
        }
    }
}

