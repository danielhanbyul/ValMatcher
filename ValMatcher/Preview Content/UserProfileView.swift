//
//  UserProfileView.swift
//  ValMatcher
//
//  Created by Daniel Han on 7/22/24.
//

import SwiftUI
import Firebase
import FirebaseFirestore

class UserProfileViewModel: ObservableObject {
    @Published var user: UserProfile
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init(user: UserProfile) {
        self.user = user
        startListeningForUserUpdates()
    }

    private func startListeningForUserUpdates() {
        guard let userId = user.id else {
            print("Error: User ID is nil")
            return
        }

        listener = db.collection("users").document(userId)
            .addSnapshotListener { documentSnapshot, error in
                if let error = error {
                    print("Error fetching user: \(error)")
                    return
                }
                guard let document = documentSnapshot, document.exists else {
                    print("Document does not exist")
                    return
                }
                if let data = document.data() {
                    self.user = UserProfile(
                        id: self.user.id,
                        name: data["name"] as? String ?? "",
                        rank: data["rank"] as? String ?? "",
                        imageName: data["imageName"] as? String ?? "",
                        age: data["age"] as? String ?? "",
                        server: data["server"] as? String ?? "",
                        answers: data["answers"] as? [String: String] ?? [:],
                        hasAnsweredQuestions: data["hasAnsweredQuestions"] as? Bool ?? false,
                        additionalImages: data["additionalImages"] as? [String] ?? []
                    )
                }
            }
    }

    deinit {
        listener?.remove()
    }

    func updateUserProfile(newAge: String, newRank: String, newServer: String, additionalImages: [String], updatedAnswers: [String: String]) {
        guard let userId = user.id else {
            print("Error: User ID is nil")
            return
        }

        let profileRef = db.collection("users").document(userId)
        profileRef.updateData([
            "age": newAge,
            "rank": newRank,
            "server": newServer,
            "additionalImages": additionalImages,
            "answers": updatedAnswers
        ]) { error in
            if let error = error {
                print("Error updating profile: \(error)")
            } else {
                self.user.age = newAge
                self.user.rank = newRank
                self.user.server = newServer
                self.user.additionalImages = additionalImages
                self.user.answers = updatedAnswers
            }
        }
    }
}
