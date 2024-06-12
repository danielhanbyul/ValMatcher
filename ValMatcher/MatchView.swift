//
//  MatchView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/12/24.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift

struct MatchView: View {
    @State private var users = [UserProfile]()
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
                if currentIndex < users.count {
                    UserCardView(user: users[currentIndex])
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
                loadUsers()
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Match!"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
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

    func likeAction() {
        let currentUserID = Auth.auth().currentUser?.uid ?? ""
        let likedUserID = users[currentIndex].id

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
        let currentUserID = Auth.auth().currentUser?.uid ?? ""

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
        let currentUserID = Auth.auth().currentUser?.uid ?? ""

        let db = Firestore.firestore()
        let matchData: [String: Any] = [
            "user1": currentUserID,
            "user2": likedUserID,
            "timestamp": FieldValue.serverTimestamp()
        ]

        var ref: DocumentReference? = nil
        ref = db.collection("matches").addDocument(data: matchData) { error in
            if let error = error {
                print("Error creating match: \(error.localizedDescription)")
            } else {
                print("Match created!")
                self.alertMessage = "You have matched with \(likedUserID)!"
                self.showAlert = true
                self.newMatchID = ref?.documentID

                // Optional automatic navigation
                self.navigateToChat = true
            }
            self.currentIndex += 1
        }
    }
}
