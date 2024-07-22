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
                if let user = currentUser {
                    if user.hasAnsweredQuestions {
                        ContentView(currentUser: $currentUser, isSignedIn: $isSignedIn)
                    } else {
                        QuestionsView(userProfile: Binding(
                            get: { self.currentUser ?? UserProfile(name: "", rank: "", imageName: "", age: "", server: "", answers: [:], hasAnsweredQuestions: false, additionalImages: []) },
                            set: { self.currentUser = $0 }
                        ), hasAnsweredQuestions: $hasAnsweredQuestions)
                    }
                } else {
                    Text("Loading...")
                }
            } else {
                if isShowingLoginView {
                    LoginView(isSignedIn: $isSignedIn, currentUser: $currentUser, isShowingLoginView: $isShowingLoginView)
                } else {
                    SignUpView(currentUser: $currentUser, isSignedIn: $isSignedIn, isShowingLoginView: $isShowingLoginView)
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
                            hasAnsweredQuestions: data["hasAnsweredQuestions"] as? Bool ?? false,
                            additionalImages: data["additionalImages"] as? [String] ?? []
                        )
                        self.hasAnsweredQuestions = self.currentUser?.hasAnsweredQuestions ?? false
                    }
                }
            }
        } else {
            self.isSignedIn = false
        }
    }
}
