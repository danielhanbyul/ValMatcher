//
//  FirestoreManager.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/23/24.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift

class FirestoreManager: ObservableObject {
    @Published var users = [UserProfile]()
    @Published var chats = [Chat]()

    private var db = Firestore.firestore()

    func loadUsers() {
        db.collection("users").getDocuments { snapshot, error in
            if let error = error {
                print("Error loading users: \(error.localizedDescription)")
                return
            }

            self.users = snapshot?.documents.compactMap { document in
                try? document.data(as: UserProfile.self)
            } ?? []
            
            self.users.shuffle() // Shuffle the profiles randomly
        }
    }

    func loadChats(forUserID userID: String) {
        db.collection("matches")
            .whereField("user1", isEqualTo: userID)
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
            .whereField("user2", isEqualTo: userID)
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

    func createMatch(user1: String, user2: String, completion: @escaping (String?) -> Void) {
        let matchData: [String: Any] = [
            "user1": user1,
            "user2": user2,
            "timestamp": FieldValue.serverTimestamp()
        ]

        var ref: DocumentReference? = nil
        ref = db.collection("matches").addDocument(data: matchData) { error in
            if let error = error {
                print("Error creating match: \(error.localizedDescription)")
                completion(nil)
            } else {
                print("Match created!")
                completion(ref?.documentID)
            }
        }
    }
}
