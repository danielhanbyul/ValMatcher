//
//  UserFeedViewModel.swift
//  ValMatcher
//
//  Created by Daniel Han on 1/1/25.
//

import SwiftUI
import Firebase
import FirebaseFirestore

class UserFeedViewModel: ObservableObject {
    @Published var users: [UserProfile] = []
    private var listener: ListenerRegistration?
    
    /// Keep track so we only load once
    private var isDataLoaded = false
    
    /// Keep track of user IDs the current user has liked/passed
    /// so we can exclude them from the list permanently
    var interactedUsers: Set<String> = []
    
    func loadFeedIfNeeded(currentUserID: String) {
        guard !isDataLoaded else { return }
        isDataLoaded = true
        
        // 1) First, fetch the user's "interacted" set from Firestore
        fetchInteractedUsers(currentUserID: currentUserID) {
            // 2) Then set up the snapshot listener on the "users" collection
            self.listenForUsers(currentUserID: currentUserID)
        }
    }
    
    private func fetchInteractedUsers(currentUserID: String, completion: @escaping () -> Void) {
        let db = Firestore.firestore()
        db.collection("users").document(currentUserID).getDocument { document, error in
            if let document = document, document.exists {
                if let interacted = document.data()?["interactedUsers"] as? [String] {
                    self.interactedUsers = Set(interacted)
                }
            }
            
            // Also load from UserDefaults if you prefer offline caching:
            if let savedInteracted = UserDefaults.standard.array(forKey: "interactedUsers_\(currentUserID)") as? [String] {
                self.interactedUsers = self.interactedUsers.union(savedInteracted)
            }
            
            completion()
        }
    }
    
    private func listenForUsers(currentUserID: String) {
        let db = Firestore.firestore()
        
        // Order by createdAt ascending to get stable ordering
        listener = db.collection("users")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening for users: \(error.localizedDescription)")
                    return
                }
                guard let snapshot = snapshot else { return }
                
                for change in snapshot.documentChanges {
                    let doc = change.document
                    // Attempt to parse into your UserProfile model
                    guard let user = try? doc.data(as: UserProfile.self),
                          let userID = user.id else {
                        continue
                    }
                    
                    // Skip the current user
                    if userID == currentUserID { continue }
                    // Skip any user that’s been liked or passed
                    if self.interactedUsers.contains(userID) { continue }
                    
                    switch change.type {
                    case .added:
                        // Only add if not already in the list
                        if !self.users.contains(where: { $0.id == userID }) {
                            // Insert at correct position to keep ascending order by createdAt
                            self.insertUserInCreationOrder(user)
                        }
                        
                    case .modified:
                        // If the user is already in the list, update the data in-place
                        if let index = self.users.firstIndex(where: { $0.id == userID }) {
                            self.users[index] = user
                        }
                        
                    case .removed:
                        // Remove from the list if they are found
                        if let index = self.users.firstIndex(where: { $0.id == userID }) {
                            self.users.remove(at: index)
                        }
                    }
                }
            }
    }
    
    private func insertUserInCreationOrder(_ newUser: UserProfile) {
        guard let newCreatedAt = newUser.createdAt else {
            // If somehow there's no createdAt, just append
            self.users.append(newUser)
            return
        }
        var insertionIndex = self.users.count
        for (index, existingUser) in self.users.enumerated() {
            guard let existingCreatedAt = existingUser.createdAt else { continue }
            if newCreatedAt.dateValue() < existingCreatedAt.dateValue() {
                insertionIndex = index
                break
            }
        }
        self.users.insert(newUser, at: insertionIndex)
    }


    
    /// Call this when user swipes left or right on a user
    func userDidInteract(with userID: String, currentUserID: String) {
        // Add to "interacted" so it won't appear again
        interactedUsers.insert(userID)
        
        // Save to Firestore for persistent tracking
        saveInteractedUsers(currentUserID: currentUserID)
        
        // Remove from local array
        if let index = users.firstIndex(where: { $0.id == userID }) {
            users.remove(at: index)
        }
    }
    
    private func saveInteractedUsers(currentUserID: String) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(currentUserID)
        
        userRef.updateData(["interactedUsers": Array(interactedUsers)]) { error in
            if let error = error {
                print("Error saving interacted users: \(error.localizedDescription)")
            }
        }
        
        // Also store locally for offline
        UserDefaults.standard.set(Array(interactedUsers), forKey: "interactedUsers_\(currentUserID)")
    }
    
    deinit {
        // Stop listening when the VM is deallocated
        listener?.remove()
    }
}
