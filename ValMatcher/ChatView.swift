//
//  ChatView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/12/24.
//

import SwiftUI
import Firebase

struct ChatView: View {
    var matchID: String
    @State private var messages = [Message]()
    @State private var newMessage = ""

    var body: some View {
        VStack {
            ScrollView {
                ForEach(messages) { message in
                    Text(message.content)
                        .padding()
                        .background(message.isCurrentUser ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .frame(maxWidth: .infinity, alignment: message.isCurrentUser ? .trailing : .leading)
                        .padding(message.isCurrentUser ? .leading : .trailing, 50)
                        .padding(.vertical, 2)
                }
            }
            .padding(.top, 10)

            HStack {
                TextField("Enter message...", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minHeight: CGFloat(30))

                Button(action: sendMessage) {
                    Text("Send")
                }
            }
            .padding()
        }
        .onAppear {
            loadMessages()
        }
    }

    func loadMessages() {
        let db = Firestore.firestore()
        db.collection("matches").document(matchID).collection("messages").order(by: "timestamp").addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error loading messages: \(error.localizedDescription)")
                return
            }

            self.messages = snapshot?.documents.compactMap { document in
                try? document.data(as: Message.self)
            } ?? []
        }
    }

    func sendMessage() {
        guard !newMessage.isEmpty else { return }

        let db = Firestore.firestore()
        let currentUserID = Auth.auth().currentUser?.uid ?? ""
        let message = Message(senderID: currentUserID, content: newMessage, timestamp: Timestamp())

        do {
            try db.collection("matches").document(matchID).collection("messages").addDocument(from: message)
            self.newMessage = ""
        } catch {
            print("Error sending message: \(error.localizedDescription)")
        }
    }
}
