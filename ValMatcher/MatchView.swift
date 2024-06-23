//
//  MatchView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/12/24.
//

import SwiftUI
import Firebase

struct MatchView: View {
    @StateObject private var firestoreManager = FirestoreManager()
    @State private var currentIndex = 0
    @State private var offset = CGSize.zero
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var navigateToChat = false
    @State private var newMatchID: String?

    var body: some View {
        ZStack {
            if navigateToChat, let newMatchID = newMatchID {
                NavigationLink(destination: DM(matchID: newMatchID), isActive: $navigateToChat) {
                    EmptyView()
                }
            }

            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            VStack {
                if currentIndex < firestoreManager.users.count {
                    UserCardView(user: firestoreManager.users[currentIndex])
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    self.offset = gesture.translation
                                }
                                .onEnded { gesture in
                                    if self.offset.width < -100 {
                                        self.dislikeAction()
                                    } else if self.offset.width > 100 {
                                        self.likeAction()
                                    }
                                    self.offset = .zero
                                }
                        )
                        .animation(.spring())
                } else {
                    Text("No more users")
                }
            }
            .onAppear {
                if !isPreview() {
                    firestoreManager.loadUsers()
                } else {
                    // Load mock data for preview
                    self.firestoreManager.users = [
                        UserProfile(name: "Alice", rank: "Bronze 1", imageName: "alice", age: "21", server: "NA", bestClip: "clip1", answers: [:]),
                        UserProfile(name: "Bob", rank: "Silver 2", imageName: "bob", age: "22", server: "EU", bestClip: "clip2", answers: [:])
                    ]
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Match!"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    func likeAction() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        guard let likedUserID = firestoreManager.users[currentIndex].id else { return }

        let db = Firestore.firestore()
        db.collection("users").document(currentUserID).collection("likes").document(likedUserID).setData([:]) { error in
            if let error = error {
                print("Error liking user: \(error.localizedDescription)")
                return
            }

            self.checkForMatch(likedUserID: likedUserID)
        }
    }

    func dislikeAction() {
        currentIndex += 1
    }

    func checkForMatch(likedUserID: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        db.collection("users").document(likedUserID).collection("likes").document(currentUserID).getDocument { document, error in
            if let error = error {
                print("Error checking for match: \(error.localizedDescription)")
                return
            }

            if document?.exists == true {
                self.createMatch(likedUserID: likedUserID)
            } else {
                self.currentIndex += 1
            }
        }
    }

    func createMatch(likedUserID: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        firestoreManager.createMatch(user1: currentUserID, user2: likedUserID) { matchID in
            if let matchID = matchID {
                self.alertMessage = "You have matched with \(likedUserID)!"
                self.showAlert = true
                self.newMatchID = matchID
                self.navigateToChat = true
            }
            self.currentIndex += 1
        }
    }
}

// Preview for MatchView
struct MatchView_Previews: PreviewProvider {
    static var previews: some View {
        MatchView()
            .environmentObject(FirestoreManager())
    }
}
