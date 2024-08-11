//
//  ContentView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/6/24.
//
import SwiftUI
import Firebase
import FirebaseFirestore
import AVKit

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
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: 0) {
                    if currentIndex < users.count {
                        userCardStack
                            .padding(.top, 40) // Add space between the top of the phone and the user card
                    } else {
                        noMoreUsersView
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Text("ValMatcher")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.top, 10) // Move the title and icons down a bit
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
                .padding(.top, 10) // Move the icons down a bit
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Notification"), message: Text(alertMessage), dismissButton: .default(Text("OK")) {
                acknowledgedNotifications.insert(alertMessage)
            })
        }
        .onAppear {
            // Fetch data only if users array is empty
            if users.isEmpty {
                fetchUsers()
                fetchIncomingLikes()
                listenForUnreadMessages()
            }
        }
    }

    private var userCardStack: some View {
        VStack(spacing: 0) {
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
                        .gesture(
                            TapGesture(count: 2)
                                .onEnded {
                                    self.likeAction()
                                }
                        )
                }

                if let result = interactionResult {
                    interactionResultView(result)
                }
            }
            .padding([.horizontal, .bottom])

            userInfoView
                .padding(.horizontal)
            
            if !users[currentIndex].additionalImages.isEmpty {
                userAdditionalImagesView
                    .padding(.horizontal)
            }
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
                ForEach(users[currentIndex].additionalImages.indices, id: \.self) { index in
                    if let urlString = users[currentIndex].additionalImages[index],
                       let url = URL(string: urlString),
                       let data = try? Data(contentsOf: url),
                       let image = UIImage(data: data) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 2))
                                .shadow(radius: 5)
                            
                            Button(action: {
                                // Handle image deletion
                                deleteImage(at: index)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .padding(4)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 3)
                            }
                            .offset(x: -10, y: 10)
                        }
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
                                        let matchMessage = "You matched with \(likedUser.name)!"
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

    private func listenForUnreadMessages() {
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
                self.updateUnreadMessagesCount(from: snapshot)
            }
        
        db.collection("matches")
            .whereField("user2", isEqualTo: currentUserID)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching matches: \(error)")
                    return
                }
                self.updateUnreadMessagesCount(from: snapshot)
            }
    }

    private func updateUnreadMessagesCount(from snapshot: QuerySnapshot?) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        var count = 0
        let group = DispatchGroup()
        
        snapshot?.documents.forEach { document in
            group.enter()
            Firestore.firestore().collection("matches").document(document.documentID).collection("messages")
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
            self.unreadMessagesCount = count
        }
    }

    private func likeAction() {
        interactionResult = .liked
        
        // Move to the next user immediately
        moveToNextUser()

        // If authenticated, handle match creation
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Error: User not authenticated")
            return
        }

        let likedUser = users[currentIndex]

        guard let likedUserID = likedUser.id else {
            print("Error: Liked user does not have an ID")
            return
        }

        let db = Firestore.firestore()

        // Save the like in the background
        DispatchQueue.global(qos: .background).async {
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
                            DispatchQueue.main.async {
                                if !self.notifications.contains(likeMessage) && !self.acknowledgedNotifications.contains(likeMessage) {
                                    self.notifications.append(likeMessage)
                                    notificationCount += 1
                                    self.sendNotification(to: likedUserID, message: likeMessage)
                                }
                            }
                        }
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
                let matchMessage = "You matched with \(likedUser.name)!"
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

    private func deleteImage(at index: Int) {
        users[currentIndex].additionalImages.remove(at: index)
        
        // Update the database or perform any additional logic needed for image deletion
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

struct NotificationsView: View {
    @Binding var notifications: [String]
    @Binding var notificationCount: Int

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                if notifications.isEmpty {
                    Text("No notifications")
                        .foregroundColor(.white)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) { // Added spacing
                            ForEach(notifications, id: \.self) { notification in
                                Text(notification)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(10)
                                    .padding(.horizontal) // Added horizontal padding
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
        }
    }
}

struct UserCardView: View {
    var user: UserProfile
    var newMedia: [MediaItem] = []
    @State private var currentMediaIndex = 0
    @State private var isEditing: Bool = false // Add this state for editing mode

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                TabView(selection: $currentMediaIndex) {
                    // Existing media
                    ForEach(user.additionalImages.indices, id: \.self) { index in
                        if let urlString = user.additionalImages[index], let url = URL(string: urlString) {
                            ZStack {
                                if url.pathExtension.lowercased() == "mp4" {
                                    VideoPlayer(player: AVPlayer(url: url))
                                        .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.5)
                                        .cornerRadius(20)
                                        .shadow(radius: 10)
                                } else {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                                .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.5)
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.5)
                                                .clipped()
                                                .cornerRadius(20)
                                                .shadow(radius: 10)
                                        case .failure:
                                            Image(systemName: "photo")
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.5)
                                                .clipped()
                                                .cornerRadius(20)
                                                .background(Color.gray)
                                                .shadow(radius: 10)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                }
                                
                                // Show delete button if in editing mode
                                if isEditing {
                                    Button(action: {
                                        deleteImage(at: index)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                            .padding(10)
                                            .background(Color.white.opacity(0.7))
                                            .clipShape(Circle())
                                    }
                                    .offset(x: 40, y: -40) // Adjust the offset to position the button on the top-right corner of the image
                                }
                            }
                        }
                    }
                    // New media
                    ForEach(newMedia.indices, id: \.self) { index in
                        let media = newMedia[index]
                        if let image = media.image {
                            ZStack {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.5)
                                    .clipped()
                                    .cornerRadius(20)
                                    .shadow(radius: 10)
                                
                                // Show delete button if in editing mode
                                if isEditing {
                                    Button(action: {
                                        deleteNewMedia(at: index)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                            .padding(10)
                                            .background(Color.white.opacity(0.7))
                                            .clipShape(Circle())
                                    }
                                    .offset(x: 40, y: -40) // Adjust the offset to position the button on the top-right corner of the image
                                }
                            }
                        } else if let videoURL = media.videoURL {
                            VideoPlayer(player: AVPlayer(url: videoURL))
                                .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.5)
                                .cornerRadius(20)
                                .shadow(radius: 10)
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                .frame(height: UIScreen.main.bounds.height * 0.5)
                
                // Navigation arrows
                HStack {
                    Button(action: {
                        currentMediaIndex = max(currentMediaIndex - 1, 0)
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 20)
                    
                    Spacer()
                    
                    Button(action: {
                        currentMediaIndex = min(currentMediaIndex + 1, (user.additionalImages.count + newMedia.count) - 1)
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                }
                
                // Page indicator
                VStack {
                    Spacer()
                    HStack {
                        ForEach(0..<(user.additionalImages.count + newMedia.count), id: \.self) { index in
                            Circle()
                                .fill(index == currentMediaIndex ? Color.white : Color.gray)
                                .frame(width: 8, height: 8)
                                .padding(2)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Username: \(user.name)")
                    Spacer()
                    Text("Age: \(user.age)")
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
        .onTapGesture {
            // Toggle editing mode when tapping the card
            isEditing.toggle()
        }
    }

    private func deleteImage(at index: Int) {
        // Logic to delete the existing image from the user's profile
    }
    
    private func deleteNewMedia(at index: Int) {
        // Logic to delete the newly added media
    }
}
