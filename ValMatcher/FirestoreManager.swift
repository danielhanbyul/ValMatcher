//
//  FirestoreManager.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/23/24.
//

import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine

class FirestoreManager: ObservableObject {
    @Published var users = [UserProfile]()

    func loadUsers() {
        // Load real data from Firestore
        let db = Firestore.firestore()
        db.collection("users").getDocuments { snapshot, error in
            if let error = error {
                print("Error loading users: \(error.localizedDescription)")
                return
            }

            self.users = snapshot?.documents.compactMap { document in
                try? document.data(as: UserProfile.self)
            } ?? []
            
            self.users.shuffle()
        }
    }

    func createMatch(user1: String, user2: String, completion: @escaping (String?) -> Void) {
        let db = Firestore.firestore()
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
                completion(ref?.documentID)
            }
        }
    }
}
