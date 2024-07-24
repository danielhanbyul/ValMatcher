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
    @StateObject private var firestoreManager = FirestoreManager()
    @State private var hasAnsweredQuestions = false
    @State private var users: [UserProfile] = []
    @State private var currentIndex = 0
    @State private var offset = CGSize.zero
    @State private var interactionResult: InteractionResult? = nil
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var notifications: [String] = []
    @State private var showNotificationBanner = false
    @State private var bannerMessage = ""
    @State private var notificationCount = 0
    @State private var acknowledgedNotifications: Set<String> = []
    @State private var unreadMessagesCount = 0

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
            }
            .navigationTitle("ValMatcher")
            .toolbar {
                topBarContent
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Notification"), message: Text(alertMessage), dismissButton: .default(Text("OK")) {
                    acknowledgedNotifications.insert(alertMessage)
                })
            }
            .onAppear {
                fetchUsers()
                fetchIncomingLikes()
                fetchUnreadMessagesCount()
            }
        }
    }

    private var userCardStack: some View {
        VStack {
            ZStack {
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
                        .offset(x: self.offset.width, y: 0)
                }

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
        Group {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Text("ValMatcher")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
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
                    NavigationLink(destination: DMHomeView(totalUnreadMessages: $unreadMessagesCount)) {
                        Image(systemName: "message.fill")
                            .foregroundColor(.white)
                            .imageScale(.medium)
                            .overlay(
                                BadgeView(count: unreadMessagesCount)
                                    .offset(x: 12, y: -12)
                            )
                    }
                    NavigationLink(destination: ProfileView(viewModel: userProfileViewModel, isSignedIn: $isSignedIn)) {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundColor(.white)
                            .imageScale(.medium)
                    }
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
                            .foregroundColor(.white)
                    }
                    Text(users[currentIndex].answers[key] ?? "")
                        .font(.custom("AvenirNext-Regular", size: 22))
                        .foregroundColor(.white)
                        .padding(.top, 2)
                }
                .frame(width: UIScreen.main.bounds.width * 0.85, alignment: .leading)
                .padding()
                .background(Color.black.opacity(0.7))
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
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Error: User not authenticated")
            return
        }

        let db = Firestore.firestore()
        db.collection("users").getDocuments { (querySnapshot, error) in
            if let error = error {
                print("Error fetching users: \(error)")
                return
            }
            self.users = querySnapshot?.documents.compactMap { document in
                let user = try? document.data(as: UserProfile.self)
                return user?.id != currentUserID ? user : nil
            } ?? []
        }
    }
    
    private func fetchIncomingLikes() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Error: User not authenticated")
            return
        }
        
        let db = Firestore.firestore()
        db.collection("likes")
            .whereField("likedUserID", isEqualTo: currentUserID)
            .addSnapshotListener { (querySnapshot, error) in
                if let error = error {
                    print("Error fetching incoming likes: \(error.localizedDescription)")
                    return
                }
                
                for document in querySnapshot?.documents ?? [] {
                    let likeData = document.data()
                    let likingUserID = likeData["likingUserID"] as? String ?? ""
                    
                    // Avoid processing the same like again
                    guard likingUserID != currentUserID else { continue }

                    // Fetch the user who liked the current user
                    db.collection("users").document(likingUserID).getDocument { (userDocument, error) in
                        if let error = error {
                            print("Error fetching liking user: \(error.localizedDescription)")
                            return
                        }
                        
                        if let userDocument = userDocument, let likedUser = try? userDocument.data(as: UserProfile.self) {
                            // Check if it's a match
                            db.collection("likes")
                                .whereField("likedUserID", isEqualTo: likingUserID)
                                .whereField("likingUserID", isEqualTo: currentUserID)
                                .getDocuments { (matchQuerySnapshot, matchError) in
                                    if let matchError = matchError {
                                        print("Error checking match: \(matchError.localizedDescription)")
                                        return
                                    }
                                    
                                    if matchQuerySnapshot?.isEmpty == false {
                                        // It's a match!
                                        let matchMessage = "You have matched with \(likedUser.name)!"
                                        if !self.notifications.contains(matchMessage) && !self.acknowledgedNotifications.contains(matchMessage) {
                                            self.alertMessage = matchMessage
                                            self.notifications.append(matchMessage)
                                            notificationCount += 1
                                            self.showAlert = true
                                            self.sendNotification(to: currentUserID, message: matchMessage)
                                            self.sendNotification(to: likingUserID, message: matchMessage)
                                            self.createDMChat(currentUserID: currentUserID, likedUserID: likingUserID, likedUser: likedUser)
                                        }
                                    } else {
                                        // Not a match, just a like
                                        let likeMessage = "\(likedUser.name) liked you!"
                                        if !self.notifications.contains(likeMessage) && !self.acknowledgedNotifications.contains(likeMessage) {
                                            self.alertMessage = likeMessage
                                            self.notifications.append(likeMessage)
                                            notificationCount += 1
                                            self.showAlert = true
                                            self.sendNotification(to: currentUserID, message: likeMessage)
                                        }
                                    }
                                }
                        }
                    }
                }
            }
    }

    private func fetchUnreadMessagesCount() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Error: User not authenticated")
            return
        }
        
        let db = Firestore.firestore()
        db.collection("matches")
            .whereField("user1", isEqualTo: currentUserID)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching matches: \(error)")
                    return
                }

                var count = 0
                let group = DispatchGroup()
                snapshot?.documents.forEach { document in
                    group.enter()
                    db.collection("matches").document(document.documentID).collection("messages")
                        .whereField("senderID", isNotEqualTo: currentUserID)
                        .whereField("isRead", isEqualTo: false)
                        .getDocuments { messageSnapshot, error in
                            if let error = error {
                                print("Error fetching messages: \(error)")
                                return
                            }

                            count += messageSnapshot?.documents.count ?? 0
                            group.leave()
                        }
                }
                group.notify(queue: .main) {
                    unreadMessagesCount = count
                }
            }
        
        db.collection("matches")
            .whereField("user2", isEqualTo: currentUserID)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching matches: \(error)")
                    return
                }

                var count = 0
                let group = DispatchGroup()
                snapshot?.documents.forEach { document in
                    group.enter()
                    db.collection("matches").document(document.documentID).collection("messages")
                        .whereField("senderID", isNotEqualTo: currentUserID)
                        .whereField("isRead", isEqualTo: false)
                        .getDocuments { messageSnapshot, error in
                            if let error = error {
                                print("Error fetching messages: \(error)")
                                return
                            }

                            count += messageSnapshot?.documents.count ?? 0
                            group.leave()
                        }
                }
                group.notify(queue: .main) {
                    unreadMessagesCount = count
                }
            }
    }

    private func likeAction() {
        interactionResult = .liked
        let likedUser = users[currentIndex]

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

        // Save the like
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
                    // Send a like notification
                    let likeMessage = "You liked \(likedUser.name)'s profile!"
                    if !self.notifications.contains(likeMessage) && !self.acknowledgedNotifications.contains(likeMessage) {
                        self.notifications.append(likeMessage)
                        notificationCount += 1
                        self.sendNotification(to: likedUserID, message: likeMessage)
                    }
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
                let matchMessage = "You have matched with \(likedUser.name)!"
                if !self.notifications.contains(matchMessage) && !self.acknowledgedNotifications.contains(matchMessage) {
                    self.notifications.append(matchMessage)
                    notificationCount += 1
                    self.showAlert = true
                    self.sendNotification(to: currentUserID, message: matchMessage)
                    self.sendNotification(to: likedUserID, message: matchMessage)
                }

                // Create a DM chat between the two users
                self.createDMChat(currentUserID: currentUserID, likedUserID: likedUserID, likedUser: likedUser)
            }
        }
    }

    private func createDMChat(currentUserID: String, likedUserID: String, likedUser: UserProfile) {
        let db = Firestore.firestore()
        let chatData: [String: Any] = [
            "user1": currentUserID,
            "user2": likedUserID,
            "user1Name": userProfileViewModel.user.name, // Ensure you pass user name
            "user2Name": likedUser.name, // Ensure you pass liked user name
            "user1Image": userProfileViewModel.user.imageName, // Ensure you pass user image
            "user2Image": likedUser.imageName, // Ensure you pass liked user image
            "recipientName": likedUser.name,  // Add recipientName
            "hasUnreadMessages": true, // Add hasUnreadMessages
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
            self.offset = .zero
            if self.currentIndex < self.users.count - 1 {
                self.currentIndex += 1
            } else {
                self.currentIndex = 0
            }
        }
    }
}

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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(userProfileViewModel: UserProfileViewModel(user: UserProfile(
            id: "1",
            name: "Preview User",
            rank: "Gold 3",
            imageName: "preview",
            age: "24",
            server: "NA",
            answers: [
                "Favorite agent to play in Valorant?": "Jett",
                "Preferred role?": "Duelist",
                "Favorite game mode?": "Competitive",
                "Servers?": "NA",
                "Favorite weapon skin?": "Phantom"
            ],
            hasAnsweredQuestions: true,
            additionalImages: []
        )), isSignedIn: .constant(true))
    }
}
