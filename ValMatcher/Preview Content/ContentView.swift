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
import FirebaseAnalytics
import UserNotifications

struct ContentView: View {
    @StateObject var userProfileViewModel: UserProfileViewModel
    @Binding var isSignedIn: Bool
    @StateObject private var firestoreManager = FirestoreManager()
    @State private var hasAnsweredQuestions = false
    @State private var users: [UserProfile] = []
    @State private var currentIndex = 0
    @State private var interactionResult: InteractionResult? = nil
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var notifications: [String] = []
    @State private var showNotificationBanner = false
    @State private var bannerMessage = ""
    @State private var notificationCount = 0
    @State private var acknowledgedNotifications: Set<String> = []
    @State private var unreadMessagesCount = 0
    @State private var messageListeners: [String: ListenerRegistration] = [:]  // Dictionary to hold listeners

    enum InteractionResult {
        case liked
        case passed
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: 0) {
                    if currentIndex < users.count {
                        userCardStack
                            .padding(.top, 40)
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
                    .padding(.top, 10)
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
                .padding(.top, 10)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Notification"), message: Text(alertMessage), dismissButton: .default(Text("OK")) {
                acknowledgedNotifications.insert(alertMessage)
            })
        }
        .onAppear {
            if users.isEmpty {
                fetchUsers()
                fetchIncomingLikes()
                listenForUnreadMessages()  // Ensure that the listeners are set up for new messages
            }
        }
        .onChange(of: users) { _ in
            listenForUnreadMessages()
        }
    }

    private var userCardStack: some View {
        VStack(spacing: 0) {
            ZStack {
                if currentIndex < users.count {
                    UserCardView(user: users[currentIndex])
                        .gesture(
                            DragGesture(minimumDistance: 20)
                                .onEnded { gesture in
                                    if gesture.translation.width < -100 {
                                        self.passAction()
                                    } else if gesture.translation.width > 100 {
                                        self.likeAction()
                                    }
                                }
                        )
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

                    guard likingUserID != currentUserID else { continue }

                    db.collection("users").document(likingUserID).getDocument { (userDocument, error) in
                        if let error = error {
                            print("Error fetching liking user: \(error.localizedDescription)")
                            return
                        }

                        if let userDocument = userDocument, let likedUser = try? userDocument.data(as: UserProfile.self) {
                            db.collection("likes")
                                .whereField("likedUserID", isEqualTo: likingUserID)
                                .whereField("likingUserID", isEqualTo: currentUserID)
                                .getDocuments { (matchQuerySnapshot, matchError) in
                                    if let matchError = matchError {
                                        print("Error checking match: \(matchError.localizedDescription)")
                                        return
                                    }

                                    if matchQuerySnapshot?.isEmpty == false {
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
        let matchesRef = db.collection("matches")

        // Listen for changes in the matches collection where the current user is involved
        matchesRef.whereField("user1", isEqualTo: currentUserID).addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error fetching matches: \(error)")
                return
            }

            snapshot?.documents.forEach { document in
                self.listenForNewMessages(in: db, matchID: document.documentID, currentUserID: currentUserID)
            }
        }

        matchesRef.whereField("user2", isEqualTo: currentUserID).addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error fetching matches: \(error)")
                return
            }

            snapshot?.documents.forEach { document in
                self.listenForNewMessages(in: db, matchID: document.documentID, currentUserID: currentUserID)
            }
        }
    }

    private func listenForNewMessages(in db: Firestore, matchID: String, currentUserID: String) {
        let messageQuery = db.collection("matches").document(matchID).collection("messages")
            .order(by: "timestamp")

        // Store the listener in the dictionary
        let listener = messageQuery.addSnapshotListener { messageSnapshot, error in
            if let error = error {
                print("Error fetching messages: \(error)")
                return
            }

            let newMessages = messageSnapshot?.documentChanges.filter { $0.type == .added } ?? []

            if !newMessages.isEmpty {
                let firstNewMessage = newMessages.first
                let senderID = firstNewMessage?.document.data()["senderID"] as? String
                let messageText = firstNewMessage?.document.data()["text"] as? String ?? "You have a new message"
                let isRead = firstNewMessage?.document.data()["isRead"] as? Bool ?? true

                // Only notify if the message is unread and not sent by the current user
                if let senderID = senderID, senderID != currentUserID && !isRead {
                    db.collection("users").document(senderID).getDocument { document, error in
                        if let error = error {
                            print("Error fetching sender's name: \(error)")
                            return
                        }

                        let senderName = document?.data()?["name"] as? String ?? "Unknown User"
                        self.notifyUserOfNewMessages(senderName: senderName, messageText: messageText)
                        self.updateUnreadMessagesCount()
                    }
                }
            }
        }

        // Store the listener so it remains active
        self.messageListeners[matchID] = listener
    }


    private func updateUnreadMessagesCount() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        var count = 0
        let group = DispatchGroup()

        Firestore.firestore().collection("matches")
            .whereField("user1", isEqualTo: currentUserID)
            .getDocuments { snapshot, error in
                snapshot?.documents.forEach { document in
                    group.enter()
                    Firestore.firestore().collection("matches").document(document.documentID).collection("messages")
                        .whereField("senderID", isNotEqualTo: currentUserID)
                        .whereField("isRead", isEqualTo: false)
                        .getDocuments { messageSnapshot, error in
                            count += messageSnapshot?.documents.count ?? 0
                            group.leave()
                        }
                }
                group.notify(queue: .main) {
                    self.unreadMessagesCount = count
                }
            }
    }


    private func notifyUserOfNewMessages(senderName: String, messageText: String) {
        // Trigger an in-app notification
        let alertMessage = "\(senderName): \(messageText)"
        showNotification(title: "New Message", body: alertMessage)

        // Also trigger a system notification
        let content = UNMutableNotificationContent()
        content.title = "New Message from \(senderName)"
        content.body = messageText
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    

    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func likeAction() {
        interactionResult = .liked

        moveToNextUser()

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

                db.collection("likes")
                    .whereField("likedUserID", isEqualTo: currentUserID)
                    .whereField("likingUserID", isEqualTo: likedUserID)
                    .getDocuments { (querySnapshot, error) in
                        if let error = error {
                            print("Error checking likes: \(error.localizedDescription)")
                            return
                        }

                        if querySnapshot?.isEmpty == false {
                            self.createMatch(currentUserID: currentUserID, likedUserID: likedUserID, likedUser: likedUser)
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

        // Check if a match already exists between these two users
        db.collection("matches")
            .whereField("user1", isEqualTo: currentUserID)
            .whereField("user2", isEqualTo: likedUserID)
            .getDocuments { querySnapshot, error in
                if let error = error {
                    print("Error checking existing match: \(error.localizedDescription)")
                    return
                }
                if querySnapshot?.documents.isEmpty == true {
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

                            self.createDMChat(currentUserID: currentUserID, likedUserID: likedUserID, likedUser: likedUser)
                        }
                    }
                }
            }
    }

    private func createDMChat(currentUserID: String, likedUserID: String, likedUser: UserProfile) {
        let db = Firestore.firestore()

        // Check if a chat already exists between the two users
        db.collection("chats")
            .whereField("user1", isEqualTo: currentUserID)
            .whereField("user2", isEqualTo: likedUserID)
            .getDocuments { querySnapshot, error in
                if let error = error {
                    print("Error checking existing chat: \(error.localizedDescription)")
                    return
                }

                if querySnapshot?.documents.isEmpty == true {
                    let chatData: [String: Any] = [
                        "user1": currentUserID,
                        "user2": likedUserID,
                        "user1Name": userProfileViewModel.user.name,
                        "user2Name": likedUser.name,
                        "user1Image": userProfileViewModel.user.imageName,
                        "user2Image": likedUser.imageName,
                        "hasUnreadMessages": true,
                        "timestamp": Timestamp()
                    ]

                    // Create chat for both users
                    db.collection("chats").addDocument(data: chatData) { error in
                        if let error = error {
                            print("Error creating chat: \(error.localizedDescription)")
                        } else {
                            print("Chat created successfully")
                        }
                    }
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

    private func passAction() {
        interactionResult = .passed

        moveToNextUser()
    }

    private func moveToNextUser() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.interactionResult = nil
            if self.currentIndex < self.users.count - 1 {
                self.currentIndex += 1
            } else {
                self.currentIndex = 0
            }
        }
    }

    private func deleteImage(at index: Int) {
        users[currentIndex].additionalImages.remove(at: index)
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
            LinearGradient(gradient: Gradient(colors: [Color.black, Color.gray]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            VStack {
                if notifications.isEmpty {
                    Text("No notifications")
                        .foregroundColor(.white)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(notifications, id: \.self) { notification in
                                Text(notification)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(10)
                                    .padding(.horizontal)
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

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                TabView(selection: $currentMediaIndex) {
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
                            }
                        }
                    }
                    ForEach(newMedia.indices, id: \.self) { index in
                        let media = newMedia[index]
                        if let image = media.image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.5)
                                .clipped()
                                .cornerRadius(20)
                                .shadow(radius: 10)
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
                .foregroundColor(.black)
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
