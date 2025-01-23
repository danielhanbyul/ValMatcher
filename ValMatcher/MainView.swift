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
    @State private var isTutorialSeen: Bool = false // Assume false until confirmed
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
                            // Show the tutorial only if NOT seen
                            if !isTutorialSeen {
                                TutorialView(isTutorialSeen: $isTutorialSeen)
                                    .onAppear {
                                        saveTutorialSeenLocallyAndRemotely()
                                    }
                                    .onChange(of: isTutorialSeen) { newValue in
                                        // If tutorial has just been seen, persist locally
                                        if newValue {
                                            UserDefaults.standard.set(true, forKey: "isTutorialSeen")
                                        }
                                    }
                            } else {
                                // Already seen the tutorial, go to ContentView
                                ContentView(userProfileViewModel: UserProfileViewModel(user: user),
                                            isSignedIn: $isSignedIn)
                                    .environmentObject(appState)
                            }
                        } else {
                            // If user hasn't answered questions, show QuestionsView
                            QuestionsView(
                                userProfile: Binding(
                                    get: {
                                        self.currentUser ?? UserProfile(
                                            id: "",
                                            name: "",
                                            rank: "",
                                            imageName: "",
                                            age: 0,  // Fixed to be an integer
                                            server: "",
                                            answers: [:],
                                            hasAnsweredQuestions: false,
                                            mediaItems: []
                                        )
                                    },
                                    set: { self.currentUser = $0 }
                                ),
                                hasAnsweredQuestions: $hasAnsweredQuestions
                            )
                            .environmentObject(appState)
                        }
                    } else {
                        Text("Loading user data...")
                    }
                } else {
                    // Not signed in yet -> Show login or signup
                    if isShowingLoginView {
                        LoginView(isSignedIn: $isSignedIn,
                                  currentUser: $currentUser,
                                  isShowingLoginView: $isShowingLoginView)
                            .environmentObject(appState)
                    } else {
                        SignUpView(currentUser: $currentUser,
                                   isSignedIn: $isSignedIn,
                                   isShowingLoginView: $isShowingLoginView)
                            .environmentObject(appState)
                    }
                }
            }
        }
        .onAppear {
            checkUserStatus()
        }
        // Any match alert from appState
        .alert(isPresented: $appState.showAlert) {
            Alert(title: Text("Match Found!"),
                  message: Text(appState.alertMessage),
                  dismissButton: .default(Text("OK")))
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
                        // 1) Read 'hasSeenTutorial' from Firestore
                        let hasSeenTutorialFromFirestore = data["hasSeenTutorial"] as? Bool ?? false
                        // 2) Overwrite local isTutorialSeen only if remote says it's true
                        self.isTutorialSeen = hasSeenTutorialFromFirestore
                        UserDefaults.standard.set(hasSeenTutorialFromFirestore, forKey: "isTutorialSeen")

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

                        // Handle age conversion safely
                        let ageValue = data["age"]
                        let userAge: Int

                        if let ageInt = ageValue as? Int {
                            userAge = ageInt
                        } else if let ageString = ageValue as? String, let ageConverted = Int(ageString) {
                            userAge = ageConverted
                        } else {
                            userAge = 0  // Default to 0 if parsing fails
                        }

                        self.currentUser = UserProfile(
                            id: document.documentID,
                            name: data["name"] as? String ?? "",
                            rank: data["rank"] as? String ?? "",
                            imageName: data["imageName"] as? String ?? "",
                            age: userAge,  // Fixed conversion issue
                            server: data["server"] as? String ?? "",
                            answers: data["answers"] as? [String: String] ?? [:],
                            hasAnsweredQuestions: data["hasAnsweredQuestions"] as? Bool ?? false,
                            mediaItems: mediaItems
                        )

                        self.hasAnsweredQuestions = self.currentUser?.hasAnsweredQuestions ?? false

                        DispatchQueue.main.async {
                            if !self.hasAnsweredQuestions {
                                self.isShowingLoginView = false
                            }
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

    // Save tutorial completion both locally and remotely
    private func saveTutorialSeenLocallyAndRemotely() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        db.collection("users").document(uid).updateData(["hasSeenTutorial": true]) { err in
            if let err = err {
                print("Error saving tutorial completion: \(err.localizedDescription)")
            } else {
                print("Tutorial completion saved.")
                UserDefaults.standard.set(true, forKey: "isTutorialSeen")
            }
        }
    }
}
