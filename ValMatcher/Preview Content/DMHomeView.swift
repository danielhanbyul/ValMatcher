//
//  DMHomeView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/12/24.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift

struct DMHomeView: View {
    @State private var chats = [Chat]()

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all)

                VStack {
                    Text("Direct Messages")
                        .font(.custom("AvenirNext-Bold", size: 28))
                        .foregroundColor(.white)
                        .padding(.top, 50)
                        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)

                    ScrollView {
                        ForEach(chats) { chat in
                            NavigationLink(destination: DM(matchID: chat.id ?? "")) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Chat with \(chat.user2)")
                                            .font(.custom("AvenirNext-Bold", size: 18))
                                            .foregroundColor(.white)
                                        Text("Last message at \(chat.timestamp.dateValue(), formatter: dateFormatter)")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    Spacer()
                                }
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(12)
                                .padding(.horizontal)
                                .padding(.vertical, 5)
                                .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)
                            }
                        }
                    }
                    .padding(.top, 10)
                }
            }
            .onAppear {
                if isPreview() {
                    self.chats = [
                        Chat(id: "1", user1: "user1", user2: "user2", timestamp: Timestamp(date: Date())),
                        Chat(id: "2", user1: "user1", user2: "user3", timestamp: Timestamp(date: Date().addingTimeInterval(-86400)))
                    ]
                } else {
                    loadChats()
                }
            }
        }
    }

    func loadChats() {
        let currentUserID = Auth.auth().currentUser?.uid ?? ""
        let db = Firestore.firestore()
        
        db.collection("matches")
            .whereField("user1", isEqualTo: currentUserID)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error loading chats: \(error.localizedDescription)")
                    return
                }

                self.chats = snapshot?.documents.compactMap { document in
                    try? document.data(as: Chat.self)
                } ?? []
            }

        db.collection("matches")
            .whereField("user2", isEqualTo: currentUserID)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error loading chats: \(error.localizedDescription)")
                    return
                }

                let moreChats = snapshot?.documents.compactMap { document in
                    try? document.data(as: Chat.self)
                } ?? []
                
                self.chats.append(contentsOf: moreChats)
            }
    }

    private func isPreview() -> Bool {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
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
        DMHomeView()
            .preferredColorScheme(.dark)
    }
}
