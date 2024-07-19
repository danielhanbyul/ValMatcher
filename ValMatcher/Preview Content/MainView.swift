//
//  MainView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/30/24.
//

import SwiftUI
import Firebase

struct MainView: View {
    @State private var currentUser: UserProfile? = nil
    @State private var isSignedIn = false
    @State private var hasAnsweredQuestions = false

    var body: some View {
        NavigationView {
            if !isSignedIn {
                SignUpView(currentUser: $currentUser, isSignedIn: $isSignedIn)
            } else if !hasAnsweredQuestions {
                if let user = currentUser {
                    QuestionsView(userProfile: Binding(get: { user }, set: { currentUser = $0 }), hasAnsweredQuestions: $hasAnsweredQuestions)
                }
            } else {
                if let user = currentUser {
                    ProfileView(user: Binding(get: { user }, set: { currentUser = $0 }))
                }
            }
        }
        .onAppear {
            checkUserStatus()
        }
    }

    func checkUserStatus() {
        if let user = Auth.auth().currentUser {
            self.isSignedIn = true
            // Fetch user profile from Firestore and set hasAnsweredQuestions accordingly
            let db = Firestore.firestore()
            db.collection("users").document(user.uid).getDocument { document, error in
                if let document = document, document.exists {
                    if let data = document.data() {
                        self.currentUser = UserProfile(
                            id: document.documentID,
                            name: data["name"] as? String ?? "",
                            rank: data["rank"] as? String ?? "",
                            imageName: data["imageName"] as? String ?? "",
                            age: data["age"] as? String ?? "",
                            server: data["server"] as? String ?? "",
                            bestClip: data["bestClip"] as? String ?? "",
                            answers: data["answers"] as? [String: String] ?? [:],
                            hasAnsweredQuestions: data["hasAnsweredQuestions"] as? Bool ?? false
                        )
                        self.hasAnsweredQuestions = self.currentUser?.hasAnsweredQuestions ?? false
                    }
                }
            }
        }
    }
}
