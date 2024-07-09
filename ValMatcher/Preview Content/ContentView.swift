//
//  ContentView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/6/24.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift
import SwiftUI

struct ContentView: View {
    @State private var users = [
        UserProfile(name: "Alice", rank: "Bronze 1", imageName: "alice", age: "21", server: "NA", bestClip: "clip1", answers: [
            "Favorite agent to play in Valorant?": "Jett",
            "Preferred role?": "Duelist",
            "Favorite game mode?": "Competitive",
            "Servers?": "NA",
            "Favorite weapon skin?": "Phantom"
        ]),
        UserProfile(name: "Bob", rank: "Silver 2", imageName: "bob", age: "22", server: "EU", bestClip: "clip2", answers: [
            "Favorite agent to play in Valorant?": "Sage",
            "Preferred role?": "Controller",
            "Favorite game mode?": "Unrated",
            "Servers?": "EU",
            "Favorite weapon skin?": "Vandal"
        ]),
        // Add more users...
    ]
    @State private var currentIndex = 0
    @State private var offset = CGSize.zero
    @State private var interactionResult: InteractionResult? = nil
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var navigateToChat = false
    @State private var newMatchID: String?
    @State private var notifications: [String] = []

    enum InteractionResult {
        case liked
        case passed
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all)

                ScrollView {
                    VStack {
                        if currentIndex < users.count {
                            VStack {
                                ZStack {
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
                                        .gesture(
                                            TapGesture(count: 2)
                                                .onEnded {
                                                    self.likeAction()
                                                }
                                        )
                                        .offset(x: self.offset.width * 1.5, y: self.offset.height)
                                        .animation(.spring())
                                        .transition(.slide)

                                    if let result = interactionResult {
                                        if result == .liked {
                                            Image(systemName: "heart.fill")
                                                .resizable()
                                                .frame(width: 100, height: 100)
                                                .foregroundColor(.green)
                                                .transition(.opacity)
                                        } else if result == .passed {
                                            Image(systemName: "xmark.circle.fill")
                                                .resizable()
                                                .frame(width: 100, height: 100)
                                                .foregroundColor(.red)
                                                .transition(.opacity)
                                        }
                                    }
                                }
                                .padding()

                                VStack(alignment: .leading, spacing: 20) {
                                    ForEach(users[currentIndex].answers.keys.sorted(), id: \.self) { key in
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Image(systemName: "questionmark.circle")
                                                    .foregroundColor(.blue)
                                                Text(key)
                                                    .font(.custom("AvenirNext-Bold", size: 18))
                                                    .foregroundColor(.black)
                                            }
                                            Text(users[currentIndex].answers[key] ?? "")
                                                .font(.custom("AvenirNext-Regular", size: 22))
                                                .foregroundColor(.black)
                                                .padding(.top, 2)
                                        }
                                        .padding()
                                        .background(Color.white)
                                        .cornerRadius(10)
                                        .padding(.horizontal)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        } else {
                            VStack {
                                Text("No more users")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                                    .padding()

                                NavigationLink(destination: QuestionsView(userProfile: .constant(users[currentIndex]))) {
                                    Text("Answer Questions")
                                        .foregroundColor(.white)
                                        .font(.custom("AvenirNext-Bold", size: 18))
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.blue)
                                        .cornerRadius(8)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("ValMatcher")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 15) {
                        NavigationLink(destination: NotificationsView(notifications: $notifications)) {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.white)
                                .imageScale(.medium)
                        }
                        NavigationLink(destination: DMHomeView()) {
                            Image(systemName: "message.fill")
                                .foregroundColor(.white)
                                .imageScale(.medium)
                        }
                        NavigationLink(destination: ProfileView(user: UserProfile(name: "Your Name", rank: "Your Rank", imageName: "yourImage", age: "Your Age", server: "Your Server", bestClip: "Your Clip", answers: [:], hasAnsweredQuestions: true))) {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundColor(.white)
                                .imageScale(.medium)
                        }
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Match!"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func likeAction() {
        interactionResult = .liked
        let likedUser = users[currentIndex]

        // Add the liked user to the notifications
        notifications.append("You have liked \(likedUser.name)'s profile.")

        // Move to the next user
        moveToNextUser()

        // If authenticated, handle match creation
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Error: User not authenticated")
            return
        }

        guard let likedUserID = likedUser.id else {
            print("Error: Liked user does not have an ID")
            return
        }

        let db = Firestore.firestore()

        // Check if the liked user has already liked the current user
        db.collection("likes")
            .whereField("likedUserID", isEqualTo: currentUserID)
            .whereField("likingUserID", isEqualTo: likedUserID)
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error checking likes: \(error.localizedDescription)")
                    return
                }

                if querySnapshot?.isEmpty == false {
                    // It's a match!
                    self.createMatch(currentUserID: currentUserID, likedUserID: likedUserID, likedUser: likedUser)
                } else {
                    // Not a match, just save the like
                    self.saveLike(currentUserID: currentUserID, likedUserID: likedUserID, likedUser: likedUser)
                }
            }
    }

    private func saveLike(currentUserID: String, likedUserID: String, likedUser: UserProfile) {
        let db = Firestore.firestore()
        let likeData: [String: Any] = [
            "likingUserID": currentUserID,
            "likedUserID": likedUserID,
            "timestamp": Timestamp()
        ]

        db.collection("likes").addDocument(data: likeData) { error in
            if let error = error {
                print("Error saving like: \(error.localizedDescription)")
            } else {
                print("Like saved successfully")
                self.sendNotification(to: likedUserID, message: "\(likedUser.name) liked your profile.")
            }
        }
    }

    private func createMatch(currentUserID: String, likedUserID: String, likedUser: UserProfile) {
        let db = Firestore.firestore()
        let matchData: [String: Any] = [
            "user1": currentUserID,
            "user2": likedUserID,
            "timestamp": Timestamp()
        ]

        db.collection("matches").addDocument(data: matchData) { error in
            if let error = error {
                print("Error creating match: \(error.localizedDescription)")
            } else {
                self.alertMessage = "You have matched with \(likedUser.name)!"
                self.notifications.append("You have matched with \(likedUser.name)!")
                self.sendNotification(to: likedUserID, message: "You have matched with \(likedUser.name)!")
                self.showAlert = true

                // Create a DM chat between the two users
                self.createDMChat(currentUserID: currentUserID, likedUserID: likedUserID)
            }
        }
    }

    private func createDMChat(currentUserID: String, likedUserID: String) {
        let db = Firestore.firestore()
        let chatData: [String: Any] = [
            "user1": currentUserID,
            "user2": likedUserID,
            "messages": [],
            "timestamp": Timestamp()
        ]

        db.collection("chats").addDocument(data: chatData) { error in
            if let error = error {
                print("Error creating chat: \(error.localizedDescription)")
            } else {
                print("Chat created successfully")
            }
        }
    }

    private func sendNotification(to userID: String, message: String) {
        let db = Firestore.firestore()
        let notificationData: [String: Any] = [
            "userID": userID,
            "message": message,
            "timestamp": Timestamp()
        ]

        db.collection("notifications").addDocument(data: notificationData) { error in
            if let error = error {
                print("Error sending notification: \(error.localizedDescription)")
            } else {
                print("Notification sent successfully")
            }
        }
    }

    private func dislikeAction() {
        interactionResult = .passed
        moveToNextUser()
    }

    private func moveToNextUser() {
        DispatchQueue.main.async {
            self.interactionResult = nil
            if self.currentIndex < self.users.count - 1 {
                self.currentIndex += 1
            } else {
                self.currentIndex = 0
            }
        }
    }
}

// UserCardView Definition
struct UserCardView: View {
    var user: UserProfile

    var body: some View {
        VStack(spacing: 0) {
            Image(user.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.5)
                .clipped()
                .cornerRadius(20)
                .shadow(radius: 10)
                .overlay(
                    VStack {
                        Spacer()
                        HStack {
                            Text("\(user.name), \(user.rank)")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding([.leading, .bottom], 10)
                                .shadow(radius: 5)
                            Spacer()
                        }
                    }
                )
                .padding(.bottom, 5)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Age: \(user.age)")
                    Spacer()
                    Text("Server: \(user.server)")
                }
                .foregroundColor(.white)
                .font(.subheadline)
                .padding(.horizontal)

                HStack {
                    Text("Best Clip: \(user.bestClip)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal)
            }
            .frame(width: UIScreen.main.bounds.width * 0.85)
            .padding()
            .background(Color(.systemGray5))
            .cornerRadius(20)
            .padding(.top, 5)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray4))
        )
        .padding()
    }
}

// NotificationsView Definition
struct NotificationsView: View {
    @Binding var notifications: [String]

    var body: some View {
        VStack {
            if notifications.isEmpty {
                Text("No notifications")
                    .foregroundColor(.white)
            } else {
                List(notifications, id: \.self) { notification in
                    Text(notification)
                        .foregroundColor(.white)
                }
            }
        }
        .navigationBarTitle("Notifications", displayMode: .inline)
        .background(Color(red: 0.02, green: 0.18, blue: 0.15).edgesIgnoringSafeArea(.all))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
