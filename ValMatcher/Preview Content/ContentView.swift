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

struct ContentView: View {
    @State private var users = [
        UserProfile(name: "Alice", rank: "Bronze 1", imageName: "alice", age: "21", server: "NA", bestClip: "clip1", answers: [:]),
        UserProfile(name: "Bob", rank: "Silver 2", imageName: "bob", age: "22", server: "EU", bestClip: "clip2", answers: [:]),
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

                VStack {
                    if currentIndex < users.count {
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
                    } else {
                        VStack {
                            Text("No more users")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                                .padding()

                            NavigationLink(destination: QuestionsView()) {
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

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        NavigationLink(destination: DMHomeView()) {
                            Text("DM Home")
                                .foregroundColor(.white)
                                .font(.custom("AvenirNext-Bold", size: 18))
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(8)
                                .padding(.trailing)
                        }
                    }
                }
            }
            .navigationBarTitle("Home", displayMode: .inline)
            .navigationBarItems(trailing: HStack {
                NavigationLink(destination: NotificationsView(notifications: $notifications)) {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.white)
                        .imageScale(.large)
                        .padding()
                }
            })
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

        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            // Handle preview scenario
            self.alertMessage = "You have matched with \(likedUser.name)!"
            self.showAlert = true
            return
        }

        // Check if they already have a chat
        let db = Firestore.firestore()
        
        db.collection("matches")
            .whereField("user1", isEqualTo: currentUserID)
            .whereField("user2", isEqualTo: likedUserID)
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error checking existing chat: \(error.localizedDescription)")
                    return
                }

                if querySnapshot?.isEmpty ?? true {
                    // No existing chat, create a new one
                    let chat = Chat(user1: currentUserID, user2: likedUserID, timestamp: Timestamp())
                    do {
                        try db.collection("matches").addDocument(from: chat) { error in
                            if let error = error {
                                print("Error creating chat: \(error.localizedDescription)")
                            } else {
                                self.alertMessage = "You have matched with \(likedUser.name)!"
                                self.notifications.append("You have matched with \(likedUser.name)!")
                                self.showAlert = true
                                self.newMatchID = chat.id
                                self.navigateToChat = true
                            }
                        }
                    } catch {
                        print("Error creating chat: \(error.localizedDescription)")
                    }
                } else {
                    self.alertMessage = "You have matched with \(likedUser.name)!"
                    self.notifications.append("You have matched with \(likedUser.name)!")
                    self.showAlert = true
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
                self.currentIndex += 1
            }
        }
    }
}

// Subview for User Cards
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
            .background(Color(.systemGray6).opacity(0.8))
            .cornerRadius(20)
            .shadow(radius: 5)
            .padding(.top, 5)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.9))
                .shadow(radius: 5)
        )
        .padding()
    }
}

// View for Notifications
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

// Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.colorScheme, .dark)
    }
}
