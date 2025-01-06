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
                    guard let user = try? doc.data(as: UserProfile.self),
                          let userID = user.id else { continue }
                    
                    // Skip current user
                    if userID == currentUserID { continue }

                    // Skip users already interacted with
                    if self.interactedUsers.contains(userID) { continue }

                    // Include profileUpdated users but reset profileUpdated
                    if user.profileUpdated == true {
                        print("DEBUG: User \(userID) updated profile but included.")
                        self.resetProfileUpdatedFlag(for: userID)
                    }

                    switch change.type {
                    case .added:
                        if !self.users.contains(where: { $0.id == userID }) {
                            self.insertUserInCreationOrder(user)
                        }
                    case .modified:
                        if let index = self.users.firstIndex(where: { $0.id == userID }) {
                            self.users[index] = user
                            print("DEBUG: Updated user \(userID) in list.")
                        }
                    case .removed:
                        if let index = self.users.firstIndex(where: { $0.id == userID }) {
                            self.users.remove(at: index)
                            print("DEBUG: Removed user \(userID).")
                        }
                    }
                }
            }
    }

    // Helper to reset profileUpdated to false
    private func resetProfileUpdatedFlag(for userID: String) {
        let db = Firestore.firestore()
        db.collection("users").document(userID).updateData([
            "profileUpdated": false
        ]) { error in
            if let error = error {
                print("Error resetting profileUpdated: \(error.localizedDescription)")
            } else {
                print("DEBUG: profileUpdated reset for user \(userID).")
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

    private func addMediaItem(for userID: String, type: MediaType, url: URL) {
        guard let index = users.firstIndex(where: { $0.id == userID }) else {
            print("DEBUG: User with ID \(userID) not found in users list.")
            return
        }

        // Update local user data
        var updatedUser = users[index]
        updatedUser.mediaItems = (updatedUser.mediaItems ?? []) + [MediaItem(type: type, url: url)]
        updatedUser.profileUpdated = true
        users[index] = updatedUser

        // Update Firestore
        let db = Firestore.firestore()
        db.collection("users").document(userID).updateData([
            "mediaItems": updatedUser.mediaItems?.map { ["type": $0.type.rawValue, "url": $0.url.absoluteString] } ?? [],
            "profileUpdated": true
        ]) { error in
            if let error = error {
                print("Error updating media items: \(error.localizedDescription)")
            } else {
                print("DEBUG: profileUpdated set to true for user \(userID).")
            }
        }

        // Reset profileUpdated after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            db.collection("users").document(userID).updateData([
                "profileUpdated": false
            ]) { error in
                if let error = error {
                    print("Error resetting profileUpdated: \(error.localizedDescription)")
                } else {
                    print("DEBUG: profileUpdated reset to false for user \(userID).")
                }
            }
        }
    }



    private func saveUserProfile(updates: [String: Any], user: UserProfile) {
        guard let userID = user.id else { return }
        let db = Firestore.firestore()

        db.collection("users").document(userID).updateData(updates) { error in
            if let error = error {
                print("Error updating user profile: \(error.localizedDescription)")
            } else {
                print("Successfully updated user profile.")
            }
        }
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
