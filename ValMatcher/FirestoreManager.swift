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
        
        let user1Ref = db.collection("users").document(user1)
        let user2Ref = db.collection("users").document(user2)

        // Check if a match already exists between the two users
        db.collection("matches")
            .whereField("user1", isEqualTo: user1)
            .whereField("user2", isEqualTo: user2)
            .getDocuments { (snapshot, error) in
                if let error = error {
                    print("Error checking existing match: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                if let existingMatch = snapshot?.documents.first {
                    // Match already exists
                    print("Match already exists with ID: \(existingMatch.documentID)")
                    completion(existingMatch.documentID)
                    return
                }
                
                // Check the opposite direction
                db.collection("matches")
                    .whereField("user1", isEqualTo: user2)
                    .whereField("user2", isEqualTo: user1)
                    .getDocuments { (snapshot, error) in
                        if let error = error {
                            print("Error checking existing match: \(error.localizedDescription)")
                            completion(nil)
                            return
                        }
                        
                        if let existingMatch = snapshot?.documents.first {
                            // Match already exists
                            print("Match already exists with ID: \(existingMatch.documentID)")
                            completion(existingMatch.documentID)
                            return
                        }
                        
                        // No existing match found, proceed with creating a new match
                        self.createNewMatch(user1: user1, user2: user2, user1Ref: user1Ref, user2Ref: user2Ref, completion: completion)
                    }
            }
    }

    private func createNewMatch(user1: String, user2: String, user1Ref: DocumentReference, user2Ref: DocumentReference, completion: @escaping (String?) -> Void) {
        let db = Firestore.firestore()
        
        user1Ref.getDocument { (document, error) in
            if let document = document, document.exists, let user1Data = document.data() {
                let user1Name = user1Data["name"] as? String ?? "User1"
                let user1Image = user1Data["imageName"] as? String ?? "https://example.com/default-user1-image.jpg"
                
                user2Ref.getDocument { (document, error) in
                    if let document = document, document.exists, let user2Data = document.data() {
                        let user2Name = user2Data["name"] as? String ?? "User2"
                        let user2Image = user2Data["imageName"] as? String ?? "https://example.com/default-user2-image.jpg"
                        
                        let matchData: [String: Any] = [
                            "user1": user1,
                            "user2": user2,
                            "user1Name": user1Name,
                            "user2Name": user2Name,
                            "user1Image": user1Image,
                            "user2Image": user2Image,
                            "timestamp": FieldValue.serverTimestamp()
                        ]

                        var ref: DocumentReference? = nil
                        ref = db.collection("matches").addDocument(data: matchData) { error in
                            if let error = error {
                                print("Error creating match: \(error.localizedDescription)")
                                completion(nil)
                            } else {
                                print("Match created with ID: \(ref?.documentID ?? "Unknown ID")")
                                self.initializeChat(matchID: ref!.documentID, user1: user1, user2: user2)
                                completion(ref?.documentID)
                            }
                        }
                    } else {
                        print("Error fetching user2 data: \(error?.localizedDescription ?? "Unknown error")")
                        completion(nil)
                    }
                }
            } else {
                print("Error fetching user1 data: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
            }
        }
    }

    private func initializeChat(matchID: String, user1: String, user2: String) {
        let db = Firestore.firestore()
        let initialMessageData: [String: Any] = [
            "senderID": "system",
            "content": "Chat initialized between \(user1) and \(user2)",
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        db.collection("matches").document(matchID).collection("messages").addDocument(data: initialMessageData) { error in
            if let error = error {
                print("Error initializing chat: \(error.localizedDescription)")
            } else {
                print("Chat initialized successfully for match ID: \(matchID)")
            }
        }
    }
}
