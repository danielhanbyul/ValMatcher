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
    @State private var isShowingLoginView = true

    var body: some View {
        NavigationView {
            if isSignedIn {
                ContentView(currentUser: $currentUser, isSignedIn: $isSignedIn)
            } else {
                if isShowingLoginView {
                    LoginView(isSignedIn: $isSignedIn, currentUser: $currentUser, isShowingLoginView: $isShowingLoginView)
                } else {
                    SignUpView(currentUser: $currentUser, isSignedIn: $isSignedIn, isShowingLoginView: $isShowingLoginView)
                }
            }
        }
        .onAppear {
            print("MainView appeared")
            checkUserStatus()
        }
    }

    func checkUserStatus() {
        print("Checking user status")
        if let user = Auth.auth().currentUser {
            print("User is signed in with UID: \(user.uid)")
            self.isSignedIn = true
            let db = Firestore.firestore()
            db.collection("users").document(user.uid).getDocument { document, error in
                if let error = error {
                    print("Error fetching user document: \(error.localizedDescription)")
                } else if let document = document, document.exists {
                    if let data = document.data() {
                        self.currentUser = UserProfile(
                            id: document.documentID,
                            name: data["name"] as? String ?? "",
                            rank: data["rank"] as? String ?? "",
                            imageName: data["imageName"] as? String ?? "",
                            age: data["age"] as? String ?? "",
                            server: data["server"] as? String ?? "",
                            answers: data["answers"] as? [String: String] ?? [:],
                            hasAnsweredQuestions: data["hasAnsweredQuestions"] as? Bool ?? false
                        )
                        self.hasAnsweredQuestions = self.currentUser?.hasAnsweredQuestions ?? false
                        print("User profile set")
                    }
                } else {
                    print("User document does not exist or there was an error: \(String(describing: error))")
                }
            }
        } else {
            print("User is not signed in")
            self.isSignedIn = false
            self.isShowingLoginView = true
        }
    }
}

