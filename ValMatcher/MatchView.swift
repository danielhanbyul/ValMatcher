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
    @State private var matchedUser: UserProfile?

    var body: some View {
        ZStack {
            if navigateToChat, let newMatchID = newMatchID, let matchedUser = matchedUser {
                NavigationLink(destination: DM(
                    matchID: newMatchID,
                    recipientName: matchedUser.name,
                    recipientUserID: matchedUser.id ?? ""
                ), isActive: $navigateToChat) {
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
                firestoreManager.loadUsers()
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Match!"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }

            if let matchedUser = matchedUser {
                MatchNotificationView(matchedUser: matchedUser)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self.matchedUser = nil
                        }
                    }
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
                // Call createMatch with both currentUserID and likedUserID
                self.createMatch(currentUserID: currentUserID, likedUserID: likedUserID)
            } else {
                self.currentIndex += 1
            }
        }
    }


    func createMatch(currentUserID: String, likedUserID: String) {
        let db = Firestore.firestore()
        
        // Check if a match already exists between the two users
        db.collection("matches")
            .whereField("user1", isEqualTo: currentUserID)
            .whereField("user2", isEqualTo: likedUserID)
            .getDocuments { querySnapshot, error in
                if let error = error {
                    print("Error checking existing match: \(error.localizedDescription)")
                    return
                }
                if querySnapshot?.documents.isEmpty == true {
                    // No existing match, create a new match
                    let matchData: [String: Any] = [
                        "user1": currentUserID,
                        "user2": likedUserID,
                        "timestamp": Timestamp()
                    ]
                    db.collection("matches").addDocument(data: matchData) { error in
                        if let error = error {
                            print("Error creating match: \(error.localizedDescription)")
                        } else {
                            print("Match created successfully")

                            // Send push notifications to both users
                            sendPushNotificationToMatchedUsers(currentUserID: currentUserID, likedUserID: likedUserID)
                        }
                    }
                }
            }
    }

    private func sendPushNotificationToMatchedUsers(currentUserID: String, likedUserID: String) {
        let db = Firestore.firestore()

        // Get the FCM tokens of both users from Firestore
        let usersRef = db.collection("users")
        
        // Fetch current user's FCM token
        usersRef.document(currentUserID).getDocument { (document, error) in
            if let document = document, document.exists {
                let currentUserName = document.data()?["name"] as? String ?? "Someone"
                let currentUserFCMToken = document.data()?["fcmToken"] as? String
                
                // Debugging log
                print("DEBUG: Current user's name: \(currentUserName)")
                print("DEBUG: Current user's FCM token: \(String(describing: currentUserFCMToken))")

                // Fetch liked user's FCM token
                usersRef.document(likedUserID).getDocument { (likedUserDocument, error) in
                    if let likedUserDocument = likedUserDocument, likedUserDocument.exists {
                        let likedUserName = likedUserDocument.data()?["name"] as? String ?? "Someone"
                        let likedUserFCMToken = likedUserDocument.data()?["fcmToken"] as? String

                        // Debugging log
                        print("DEBUG: Liked user's name: \(likedUserName)")
                        print("DEBUG: Liked user's FCM token: \(String(describing: likedUserFCMToken))")

                        // Now send push notifications to both users
                        if let likedUserFCMToken = likedUserFCMToken {
                            // Push notification to liked user
                            sendFCMNotification(to: likedUserFCMToken, title: "New Match!", body: "You matched with \(currentUserName)!")
                        }
                        if let currentUserFCMToken = currentUserFCMToken {
                            // Push notification to current user
                            sendFCMNotification(to: currentUserFCMToken, title: "New Match!", body: "You matched with \(likedUserName)!")
                        }
                    } else {
                        print("Error: Liked user document not found or missing 'name' field.")
                    }
                }
            } else {
                print("Error: Current user document not found or missing 'name' field.")
            }
        }
    }
    
    

   

    func sendFCMNotification(to fcmToken: String, title: String, body: String) {
        let serverKey = "AIzaSyA-Eew48TEhrZnX80C8lyYcKkuYRx0hNME"
        let url = URL(string: "https://fcm.googleapis.com/fcm/send")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("key=\(serverKey)", forHTTPHeaderField: "Authorization")

        // Payload for the notification
        let payload: [String: Any] = [
            "to": fcmToken,
            "notification": [
                "title": title,
                "body": body,
                "sound": "default"
            ],
            "data": [
                "customDataKey": "customDataValue" // Optional custom data
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            print("DEBUG: Failed to serialize JSON for FCM payload: \(error)")
            return
        }

        // Send the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("DEBUG: Error sending FCM notification: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("DEBUG: FCM notification sent successfully with title: '\(title)' and body: '\(body)'")
            } else {
                print("DEBUG: FCM notification failed with response: \(String(describing: response))")
            }
        }
        task.resume()
    }



}

struct MatchView_Previews: PreviewProvider {
    static var previews: some View {
        MatchView()
            .environmentObject(FirestoreManager())
    }
}
