//
//  FirestoreManager.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/23/24.
//


import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine
import FirebaseAuth

class FirestoreManager: ObservableObject {
    @Published var users = [UserProfile]()
    @Published var chats = [Chat]()
    
    private var db = Firestore.firestore()
    
    // Added property to store the current user's ID
    private var currentUserID: String? {
        return Auth.auth().currentUser?.uid
    }
    
    func loadUsers() {
        print("Starting to load users...")
        db.collection("users").getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("Error loading users: \(error.localizedDescription)")
                return
            }
            
            guard let snapshot = snapshot else {
                print("Snapshot is nil. No users loaded.")
                return
            }
            
            print("Snapshot received. Number of documents: \(snapshot.documents.count)")
            
            self.users = snapshot.documents.compactMap { document in
                do {
                    let user = try document.data(as: UserProfile.self)
                    print("Loaded user: \(user)")
                    return user
                } catch {
                    print("Error decoding user data: \(error.localizedDescription)")
                    return nil
                }
            }
            
            print("Total users loaded: \(self.users.count)")
            self.users.shuffle()
            print("Users shuffled.")
        }
    }
    
    func createMatch(user1: String, user2: String, completion: @escaping (String?) -> Void) {
        print("Attempting to create match between \(user1) and \(user2)...")
        let user1Ref = db.collection("users").document(user1)
        let user2Ref = db.collection("users").document(user2)
        
        // Check if a match already exists between the two users
        db.collection("matches")
            .whereField("user1", isEqualTo: user1)
            .whereField("user2", isEqualTo: user2)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("Error checking existing match: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                if let existingMatch = snapshot?.documents.first {
                    print("Match already exists with ID: \(existingMatch.documentID)")
                    completion(existingMatch.documentID)
                    return
                }
                
                print("No existing match found for user1 and user2. Checking the opposite direction...")
                
                // Check the opposite direction
                self.db.collection("matches")
                    .whereField("user1", isEqualTo: user2)
                    .whereField("user2", isEqualTo: user1)
                    .getDocuments { [weak self] snapshot, error in
                        guard let self = self else { return }
                        if let error = error {
                            print("Error checking existing match (opposite direction): \(error.localizedDescription)")
                            completion(nil)
                            return
                        }
                        
                        if let existingMatch = snapshot?.documents.first {
                            print("Match already exists with ID: \(existingMatch.documentID)")
                            completion(existingMatch.documentID)
                            return
                        }
                        
                        print("No existing match found in both directions. Creating a new match...")
                        self.createNewMatch(user1: user1, user2: user2, user1Ref: user1Ref, user2Ref: user2Ref, completion: completion)
                    }
            }
    }
    
    private func createNewMatch(user1: String, user2: String, user1Ref: DocumentReference, user2Ref: DocumentReference, completion: @escaping (String?) -> Void) {
        print("Creating new match between \(user1) and \(user2)...")
        user1Ref.getDocument { [weak self] document, error in
            guard let self = self else { return }
            if let error = error {
                print("Error fetching user1 data: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let document = document, document.exists, let user1Data = document.data() else {
                print("User1 document does not exist or data is missing.")
                completion(nil)
                return
            }
            
            let user1Name = user1Data["name"] as? String ?? "User1"
            let user1Image = user1Data["imageName"] as? String ?? "https://example.com/default-user1-image.jpg"
            print("User1 data - Name: \(user1Name), Image: \(user1Image)")
            
            user2Ref.getDocument { [weak self] document, error in
                guard let self = self else { return }
                if let error = error {
                    print("Error fetching user2 data: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let document = document, document.exists, let user2Data = document.data() else {
                    print("User2 document does not exist or data is missing.")
                    completion(nil)
                    return
                }
                
                let user2Name = user2Data["name"] as? String ?? "User2"
                let user2Image = user2Data["imageName"] as? String ?? "https://example.com/default-user2-image.jpg"
                print("User2 data - Name: \(user2Name), Image: \(user2Image)")
                
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
                ref = self.db.collection("matches").addDocument(data: matchData) { error in
                    if let error = error {
                        print("Error creating match: \(error.localizedDescription)")
                        completion(nil)
                    } else {
                        let matchID = ref?.documentID ?? "Unknown ID"
                        print("Match created with ID: \(matchID)")
                        self.initializeChat(matchID: matchID, user1: user1, user2: user2)
                        self.loadChats() // Refresh the chat list after creating a new match
                        completion(ref?.documentID)
                    }
                }
            }
        }
    }
    
    private func initializeChat(matchID: String, user1: String, user2: String) {
        print("Initializing chat for match ID: \(matchID) between \(user1) and \(user2)...")
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
    
    func loadChats() {
        guard let currentUserID = currentUserID else {
            print("Error: currentUserID is nil")
            return
        }
        
        let db = Firestore.firestore()
        
        db.collection("matches")
            .whereField("user1", isEqualTo: currentUserID)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error loading chats for user1: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No documents for user1")
                    return
                }
                
                let newChats = documents.compactMap { document -> Chat? in
                    print("Document data: \(document.data())")
                    do {
                        let chat = try document.data(as: Chat.self)
                        print("Fetched chat for user1: \(String(describing: chat))")
                        return chat
                    } catch {
                        print("Error decoding chat for user1: \(error.localizedDescription)")
                        return nil
                    }
                }
                
                self.chats = newChats
                print("Loaded chats for user1: \(newChats)")
            }
        
        db.collection("matches")
            .whereField("user2", isEqualTo: currentUserID)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error loading chats for user2: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No documents for user2")
                    return
                }
                
                let moreChats = documents.compactMap { document -> Chat? in
                    print("Document data: \(document.data())")
                    do {
                        let chat = try document.data(as: Chat.self)
                        print("Fetched chat for user2: \(String(describing: chat))")
                        return chat
                    } catch {
                        print("Error decoding chat for user2: \(error.localizedDescription)")
                        return nil
                    }
                }
                
                self.chats.append(contentsOf: moreChats)
                self.chats = Array(Set(self.chats))
                print("Loaded chats for user2: \(moreChats)")
            }
    }
    
    func listenForUserUpdates() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("DEBUG: Current user not authenticated.")
            return
        }
        
        db.collection("users").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("DEBUG: Error listening for user updates: \(error.localizedDescription)")
                return
            }

            snapshot?.documentChanges.forEach { change in
                let document = change.document
                let userID = document.documentID
                
                switch change.type {
                case .added:
                    do {
                        let newUser = try document.data(as: UserProfile.self)
                        self.users.append(newUser)
                        print("DEBUG: User added: \(newUser)")
                    } catch {
                        print("DEBUG: Error decoding new user: \(error)")
                    }
                    
                case .modified:
                    if let index = self.users.firstIndex(where: { $0.id == userID }) {
                        do {
                            let updatedUser = try document.data(as: UserProfile.self)
                            
                            // Check if `profileUpdated` is true
                            if let profileUpdated = updatedUser.profileUpdated, profileUpdated {
                                print("DEBUG: User \(userID) has profileUpdated == true, fetching fresh data.")
                                self.fetchSingleUser(userID) { freshUser in
                                    if let freshUser = freshUser {
                                        self.users[index] = freshUser
                                        
                                        // Optionally reset `profileUpdated` in Firestore
                                        self.db.collection("users").document(userID).updateData(["profileUpdated": false]) { error in
                                            if let error = error {
                                                print("DEBUG: Error resetting profileUpdated: \(error.localizedDescription)")
                                            } else {
                                                print("DEBUG: profileUpdated reset for user \(userID)")
                                            }
                                        }
                                    }
                                }
                            } else {
                                self.users[index] = updatedUser
                            }
                        } catch {
                            print("DEBUG: Error decoding modified user: \(error)")
                        }
                    }

                case .removed:
                    self.users.removeAll { $0.id == userID }
                    print("DEBUG: User removed: \(userID)")
                }
            }
        }
    }
    
    func fetchSingleUser(_ userID: String, completion: @escaping (UserProfile?) -> Void) {
        db.collection("users").document(userID).getDocument { snapshot, error in
            if let error = error {
                print("DEBUG: Error fetching user \(userID): \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let document = snapshot, document.exists else {
                print("DEBUG: User document \(userID) does not exist.")
                completion(nil)
                return
            }
            
            do {
                let user = try document.data(as: UserProfile.self)
                print("DEBUG: Fetched single user: \(String(describing: user))")
                completion(user)
            } catch {
                print("DEBUG: Error decoding user: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }


}
