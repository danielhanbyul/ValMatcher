//
//  DM.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/12/24.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift

struct DM: View {
    var matchID: String
    @State private var messages = [Message]()
    @State private var newMessage = ""

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            VStack {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(messages) { message in
                            HStack {
                                if message.isCurrentUser {
                                    Spacer()
                                    Text(message.content)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                        .padding(.trailing, 10)
                                } else {
                                    Text(message.content)
                                        .padding()
                                        .background(Color.gray)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                        .padding(.leading, 10)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .padding(.top, 10)

                HStack {
                    TextField("Enter message...", text: $newMessage)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(minHeight: CGFloat(30))
                        .padding(.horizontal)

                    Button(action: sendMessage) {
                        Text("Send")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                            .padding(.trailing, 10)
                    }
                }
                .padding()
            }
            .onAppear {
                loadMessages()
            }
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

struct DM_Previews: PreviewProvider {
    static var previews: some View {
        DM(matchID: "sampleMatchID")
            .preferredColorScheme(.dark)
    }
}
