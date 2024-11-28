//
//  MainView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/30/24.
//

import SwiftUI
import Firebase

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentUser: UserProfile? = nil
    @State private var isSignedIn = false
    @State private var hasAnsweredQuestions = false
    @State private var isShowingLoginView = true
    @State private var isTutorialSeen: Bool = UserDefaults.standard.bool(forKey: "isTutorialSeen")
    @State private var isLoading = true // To handle loading state

    var body: some View {
        NavigationView {
            if isLoading {
                Text("Loading...")
                    .font(.title)
                    .foregroundColor(.gray)
            } else {
                if isSignedIn {
                    if let user = currentUser {
                        if user.hasAnsweredQuestions {
                            if !isTutorialSeen {
                                TutorialView(isTutorialSeen: $isTutorialSeen)
                                    .onChange(of: isTutorialSeen) { newValue in
                                        if newValue {
                                            UserDefaults.standard.set(true, forKey: "isTutorialSeen")
                                        }
                                    }
                            } else {
                                ContentView(userProfileViewModel: UserProfileViewModel(user: user), isSignedIn: $isSignedIn)
                                    .environmentObject(appState)
                            }
                        } else {
                            QuestionsView(userProfile: Binding(
                                get: { self.currentUser ?? UserProfile(id: "", name: "", rank: "", imageName: "", age: "", server: "", answers: [:], hasAnsweredQuestions: false, mediaItems: []) },
                                set: { self.currentUser = $0 }
                            ), hasAnsweredQuestions: $hasAnsweredQuestions)
                                .environmentObject(appState)
                        }
                    } else {
                        Text("Loading user data...")
                    }
                } else {
                    if isShowingLoginView {
                        LoginView(isSignedIn: $isSignedIn, currentUser: $currentUser, isShowingLoginView: $isShowingLoginView)
                            .environmentObject(appState)
                    } else {
                        SignUpView(currentUser: $currentUser, isSignedIn: $isSignedIn, isShowingLoginView: $isShowingLoginView)
                            .environmentObject(appState)
                    }
                }
            }
        }
        .onAppear {
            checkUserStatus()
        }
        .alert(isPresented: $appState.showAlert) {
            Alert(title: Text("Match Found!"), message: Text(appState.alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    // Function to check user status and navigate accordingly
    func checkUserStatus() {
        if let user = Auth.auth().currentUser {
            self.isSignedIn = true
            let db = Firestore.firestore()

            db.collection("users").document(user.uid).getDocument { document, error in
                if let error = error {
                    print("Error fetching user document: \(error.localizedDescription)")
                    self.isLoading = false
                } else if let document = document, document.exists {
                    if let data = document.data() {
                        let mediaItemsData = data["mediaItems"] as? [String] ?? []
                        let mediaItems = mediaItemsData.compactMap { urlString -> MediaItem? in
                            if let url = URL(string: urlString) {
                                if urlString.hasSuffix(".mp4") {
                                    return MediaItem(type: .video, url: url)
                                } else {
                                    return MediaItem(type: .image, url: url)
                                }
                            }
                            return nil
                        }

                        self.currentUser = UserProfile(
                            id: document.documentID,
                            name: data["name"] as? String ?? "",
                            rank: data["rank"] as? String ?? "",
                            imageName: data["imageName"] as? String ?? "",
                            age: data["age"] as? String ?? "",
                            server: data["server"] as? String ?? "",
                            answers: data["answers"] as? [String: String] ?? [:],
                            hasAnsweredQuestions: data["hasAnsweredQuestions"] as? Bool ?? false,
                            mediaItems: mediaItems
                        )

                        self.hasAnsweredQuestions = self.currentUser?.hasAnsweredQuestions ?? false

                        DispatchQueue.main.async {
                            if !self.hasAnsweredQuestions {
                                self.isShowingLoginView = false
                            } else if !self.isTutorialSeen {
                                self.isShowingLoginView = false
                            }

                            // Start listening for matches when user is authenticated
                            appState.listenForMatches()
                        }
                    }
                    self.isLoading = false
                } else {
                    self.isSignedIn = false
                    self.isLoading = false
                }
            }
        } else {
            self.isSignedIn = false
            self.isLoading = false
        }
    }
}
