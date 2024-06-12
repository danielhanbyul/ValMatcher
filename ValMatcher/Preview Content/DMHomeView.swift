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

struct Chat: Identifiable, Codable {
    @DocumentID var id: String?
    var user1: String
    var user2: String
    var timestamp: Timestamp
}

struct DMHomeView: View {
    @State private var chats = [Chat]()

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all)

                List(chats) { chat in
                    NavigationLink(destination: DM(matchID: chat.id ?? "")) {
                        VStack(alignment: .leading) {
                            Text("Chat with \(chat.user2)")
                                .font(.custom("AvenirNext-Bold", size: 18))
                                .foregroundColor(.white)
                            Text("Last message at \(chat.timestamp.dateValue(), formatter: dateFormatter)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemGray6).opacity(0.8))
                        .cornerRadius(8)
                        .shadow(radius: 5)
                    }
                    .listRowBackground(Color.clear)
                }
                .navigationTitle("Direct Messages")
                .listStyle(PlainListStyle())
                .onAppear {
                    if !isPreview() {
                        loadChats()
                    } else {
                        // Load mock data for preview
                        self.chats = [
                            Chat(id: "1", user1: "user1", user2: "user2", timestamp: Timestamp(date: Date())),
                            Chat(id: "2", user1: "user1", user2: "user3", timestamp: Timestamp(date: Date().addingTimeInterval(-86400)))
                        ]
                    }
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
