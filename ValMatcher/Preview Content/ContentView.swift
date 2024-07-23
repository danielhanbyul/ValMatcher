//
//  ContentView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/6/24.
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct ContentView: View {
    @StateObject var userProfileViewModel: UserProfileViewModel
    @Binding var isSignedIn: Bool
    @State private var hasAnsweredQuestions = false
    @State private var users: [UserProfile] = []
    @State private var currentIndex = 0
    @State private var offset = CGSize.zero
    @State private var interactionResult: InteractionResult? = nil
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var navigateToChat = false
    @State private var newMatchID: String?
    @State private var notifications: [String] = []
    @State private var showNotificationBanner = false
    @State private var bannerMessage = ""
    @State private var notificationCount = 0

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
                            userCardStack
                        } else {
                            noMoreUsersView
                        }
                    }
                }
                
                if showNotificationBanner {
                    NotificationBanner(message: bannerMessage, showBanner: $showNotificationBanner)
                        .transition(.move(edge: .top))
                        .animation(.easeInOut)
                }
            }
            .navigationTitle("ValMatcher")
            .toolbar {
                topBarContent
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Match!"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .onAppear {
                fetchUsers()
            }
        }
    }
    
    private var userCardStack: some View {
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
                    interactionResultView(result)
                }
            }
            .padding()

            userInfoView
                .padding(.horizontal)
            
            userAdditionalImagesView
                .padding(.horizontal)
        }
    }
    
    private var noMoreUsersView: some View {
        VStack {
            Text("No more users")
                .font(.largeTitle)
                .foregroundColor(.white)
                .padding()
        }
    }

    private var topBarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarLeading) {
            Text("ValMatcher")
                .font(.title2)
                .bold()
                .foregroundColor(.white)
        }
        return ToolbarItemGroup(placement: .navigationBarTrailing) {
            HStack(spacing: 15) {
                NavigationLink(destination: NotificationsView(notifications: $notifications, notificationCount: $notificationCount)) {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.white)
                        .imageScale(.medium)
                        .overlay(
                            BadgeView(count: notificationCount)
                                .offset(x: 12, y: -12)
                        )
                }
                NavigationLink(destination: DMHomeView()) {
                    Image(systemName: "message.fill")
                        .foregroundColor(.white)
                        .imageScale(.medium)
                }
                NavigationLink(destination: ProfileView(viewModel: userProfileViewModel, isSignedIn: $isSignedIn)) {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundColor(.white)
                        .imageScale(.medium)
                }
            }
        }
    }
    
    private func interactionResultView(_ result: InteractionResult) -> some View {
        Group {
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
    
    private var userInfoView: some View {
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
                .frame(width: UIScreen.main.bounds.width * 0.85, alignment: .leading)
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .padding(.horizontal)
            }
        }
    }

    private var userAdditionalImagesView: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(users[currentIndex].additionalImages, id: \.self) { imageUrl in
                    if let urlString = imageUrl,
                       let url = URL(string: urlString),
                       let data = try? Data(contentsOf: url),
                       let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 2))
                            .shadow(radius: 5)
                    }
                }
            }
        }
    }

    private func fetchUsers() {
        let db = Firestore.firestore()
        db.collection("users").getDocuments { (querySnapshot, error) in
            if let error = error {
                print("Error fetching users: \(error)")
                return
            }
            self.users = querySnapshot?.documents.compactMap { document in
                try? document.data(as: UserProfile.self)
            } ?? []
        }
    }

    private func likeAction() {
        interactionResult = .liked
        let likedUser = users[currentIndex]

        // Add the liked user to the notifications
        let notificationMessage = "\(likedUser.name) wants to play with you!"
        sendNotification(to: likedUser.id!, message: notificationMessage)
        
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
                notificationCount += 1
                self.sendNotification(to: likedUserID, message: "You have matched with \(likedUser.name)!")
                self.sendNotification(to: currentUserID, message: "You have matched with \(likedUser.name)!")
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

    private func showBanner(with message: String) {
        bannerMessage = message
        withAnimation {
            showNotificationBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showNotificationBanner = false
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

struct UserCardView: View {
    var user: UserProfile
    
    @State private var currentMediaIndex = 0
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentMediaIndex) {
                ForEach(user.additionalImages.indices, id: \.self) { index in
                    if let urlString = user.additionalImages[index],
                       let url = URL(string: urlString),
                       let data = try? Data(contentsOf: url),
                       let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.5)
                            .clipped()
                            .cornerRadius(20)
                            .shadow(radius: 10)
                            .tag(index)
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle())
            .frame(height: UIScreen.main.bounds.height * 0.5)
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


// BadgeView Definition
struct BadgeView: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(.caption2)
                .foregroundColor(.white)
                .padding(5)
                .background(Color.red)
                .clipShape(Circle())
                .offset(x: 10, y: -10)
        }
    }
}

// NotificationsView Definition
struct NotificationsView: View {
    @Binding var notifications: [String]
    @Binding var notificationCount: Int

    var body: some View {
        VStack {
            if notifications.isEmpty {
                Text("No notifications")
                    .foregroundColor(.white)
            } else {
                ScrollView {
                    VStack(alignment: .leading) {
                        ForEach(notifications, id: \.self) { notification in
                            Text(notification)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color(.systemGray5))
                                .cornerRadius(10)
                                .padding(.horizontal)
                                .padding(.vertical, 5)
                        }
                    }
                }
                .padding(.top)
            }
        }
        .onAppear {
            notificationCount = 0
        }
        .navigationBarTitle("Notifications", displayMode: .inline)
        .background(Color(red: 0.02, green: 0.18, blue: 0.15).edgesIgnoringSafeArea(.all))
    }
}

// NotificationBanner Definition
struct NotificationBanner: View {
    var message: String
    @Binding var showBanner: Bool

    var body: some View {
        VStack {
            if showBanner {
                HStack {
                    Text(message)
                        .foregroundColor(.white)
                        .padding()
                    Spacer()
                }
                .background(Color.blue)
                .cornerRadius(8)
                .padding()
                Spacer()
            }
        }
    }
}

// Previews for ContentView
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(userProfileViewModel: UserProfileViewModel(user: UserProfile(id: "", name: "Preview User", rank: "Gold 3", imageName: "preview", age: "24", server: "NA", answers: [
            "Favorite agent to play in Valorant?": "Jett",
            "Preferred role?": "Duelist",
            "Favorite game mode?": "Competitive",
            "Servers?": "NA",
            "Favorite weapon skin?": "Phantom"
        ], hasAnsweredQuestions: true, additionalImages: [])), isSignedIn: .constant(true))
    }
}
