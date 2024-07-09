//
//  RandomProfileAlgorithm.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/12/24.
//
import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift

struct RandomProfileAlgorithmView: View {
    @State private var users = [UserProfile]()

    var body: some View {
        VStack {
            if users.isEmpty {
                Text("No users available")
            } else {
                List(users) { user in
                    Text(user.name)
                }
            }
        }
        .onAppear(perform: loadUsers)
    }

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
            
            self.users.shuffle() // Shuffle the profiles randomly
        }
    }
}

