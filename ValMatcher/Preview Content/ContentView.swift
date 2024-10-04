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
import Kingfisher

struct MessageListener {
    let listener: ListenerRegistration
    private(set) var countedMessageIDs: Set<String> = []

    mutating func isAlreadyCounted(messageID: String) -> Bool {
        return countedMessageIDs.contains(messageID)
    }

    mutating func markAsCounted(messageID: String) {
        countedMessageIDs.insert(messageID)
    }

    func removeListener() {
        listener.remove()
    }
}

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
    @State private var messageListeners: [String: MessageListener] = [:]
    
    // Added States
    @State private var interactedUsers: Set<String> = []
    @State private var lastRefreshDate: Date? = nil
    @State private var shownUserIDs: Set<String> = []
    
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
            if isSignedIn {
                self.interactedUsers.removeAll()
                loadInteractedUsers { success in
                    if success {
                        fetchAllUsers()
                    }
                }
                // Set up listener for unread messages
                listenForUnreadMessagesCount()
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
            Text("No more users available")
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

    private func handleInteractions() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        let nonInteractedUsers = self.users.filter { user in
            guard let userID = user.id else { return false }
            return !self.interactedUsers.contains(userID)
        }

        self.users = nonInteractedUsers
    }

    private var userInfoView: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(profileQuestions, id: \.self) { question in
                if let answer = users[currentIndex].answers[question], !answer.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.blue)
                            Text(question)
                                .font(.custom("AvenirNext-Bold", size: 18))
                                .foregroundColor(.white)
                        }
                        Text(answer)
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
    }

    private func listenForNewUsers() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Error: User not authenticated")
            return
        }

        let db = Firestore.firestore()

        db.collection("users").addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error listening for new users: \(error.localizedDescription)")
                return
            }

            snapshot?.documentChanges.forEach { change in
                if change.type == .added {
                    if let newUser = try? change.document.data(as: UserProfile.self) {
                        guard let newUserID = newUser.id, newUserID != currentUserID else { return }

                        if !self.interactedUsers.contains(newUserID) && !self.shownUserIDs.contains(newUserID) {
                            self.users.append(newUser)
                            self.shownUserIDs.insert(newUserID)
                        }
                    }
                }
            }
            print("Users after listening for new additions: \(self.users.count)")
        }
    }

    private func fetchAllUsers() {
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

            let fetchedUsers = querySnapshot?.documents.compactMap { document in
                try? document.data(as: UserProfile.self)
            } ?? []

            let filteredUsers = fetchedUsers.filter { user in
                guard let userID = user.id else { return false }
                return userID != currentUserID && !self.interactedUsers.contains(userID)
            }

            self.users = filteredUsers
            print("Fetched users: \(self.users.count)")
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

        let listener = messageQuery.addSnapshotListener { messageSnapshot, error in
            if let error = error {
                print("Error fetching messages: \(error)")
                return
            }

            let newMessages = messageSnapshot?.documentChanges.filter { $0.type == .added } ?? []

            for change in newMessages {
                let newMessage = change.document
                let senderID = newMessage.data()["senderID"] as? String
                let messageText = newMessage.data()["text"] as? String ?? "You have a new message"
                let timestamp = newMessage.data()["timestamp"] as? Timestamp
                let isRead = newMessage.data()["isRead"] as? Bool ?? true

                if let timestamp = timestamp, !isRead, senderID != currentUserID, timestamp.dateValue().timeIntervalSinceNow > -5 {
                    db.collection("users").document(senderID!).getDocument { document, error in
                        if let error = error {
                            print("Error fetching sender's name: \(error)")
                            return
                        }

                        let senderName = document?.data()?["name"] as? String ?? "Unknown User"
                        self.notifyUserOfNewMessages(senderName: senderName, messageText: messageText)
                        self.updateUnreadMessagesCount(for: matchID, messageID: change.document.documentID)
                    }
                }
            }
        }

        self.messageListeners[matchID] = MessageListener(listener: listener)
    }

    private func updateUnreadMessagesCount(for matchID: String, messageID: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        let messageRef = db.collection("matches").document(matchID).collection("messages").document(messageID)

        messageRef.getDocument { document, error in
            if let document = document, document.exists {
                let senderID = document.data()?["senderID"] as? String
                let isRead = document.data()?["isRead"] as? Bool ?? true

                if senderID != currentUserID && !isRead {
                    if var listener = self.messageListeners[matchID], !listener.isAlreadyCounted(messageID: messageID) {
                        self.unreadMessagesCount += 1
                        listener.markAsCounted(messageID: messageID)
                        self.messageListeners[matchID] = listener
                    }
                }
            }
        }
    }

    private func showInAppNotification(for latestMessage: QueryDocumentSnapshot) {
        guard UIApplication.shared.applicationState == .active else {
            return // Prevent in-app notification if the app is not in the foreground
        }

        guard let senderName = latestMessage.data()["senderName"] as? String,
              let messageText = latestMessage.data()["text"] as? String else { return }

        let alertMessage = "\(senderName): \(messageText)"
        self.bannerMessage = alertMessage
        self.showNotificationBanner = true
    }

    private func notifyUserOfNewMessages(senderName: String, messageText: String) {
        guard UIApplication.shared.applicationState != .active else {
            return // Prevent system notification if the app is in the foreground
        }

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

    // Added function for listening to unread messages count and updating in real-time
    private func listenForUnreadMessagesCount() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()

        // Set up listener for real-time updates to unread messages count
        db.collection("users").document(currentUserID).addSnapshotListener { documentSnapshot, error in
            if let error = error {
                print("Error listening for unread messages count: \(error)")
                return
            }

            if let document = documentSnapshot, document.exists {
                if let unreadCount = document.data()?["unreadMessagesCount"] as? Int {
                    self.unreadMessagesCount = unreadCount
                }
            }
        }
    }

    private func likeAction() {
        interactionResult = .liked

        guard currentIndex < users.count else {
            return
        }

        let likedUser = users[currentIndex]

        guard let likedUserID = likedUser.id else {
            print("Error: Liked user does not have an ID")
            return
        }

        moveToNextUser()

        let db = Firestore.firestore()

        DispatchQueue.global(qos: .background).async {
            let likeData: [String: Any] = [
                "likingUserID": Auth.auth().currentUser?.uid ?? "",
                "likedUserID": likedUserID,
                "timestamp": Timestamp()
            ]
            db.collection("likes").addDocument(data: likeData) { error in
                if let error = error {
                    print("Error saving like: \(error.localizedDescription)")
                } else {
                    print("Like saved successfully")

                    db.collection("likes")
                        .whereField("likedUserID", isEqualTo: Auth.auth().currentUser?.uid ?? "")
                        .whereField("likingUserID", isEqualTo: likedUserID)
                        .getDocuments { (querySnapshot, error) in
                            if let error = error {
                                print("Error checking likes: \(error.localizedDescription)")
                                return
                            }

                            if querySnapshot?.isEmpty == false {
                                self.createMatch(currentUserID: Auth.auth().currentUser?.uid ?? "", likedUserID: likedUserID, likedUser: likedUser)
                            }
                        }
                }
            }
        }

        interactedUsers.insert(likedUserID)
        saveInteractedUsers()
    }

    private func createMatch(currentUserID: String, likedUserID: String, likedUser: UserProfile) {
        let db = Firestore.firestore()
        let matchData: [String: Any] = [
            "user1": currentUserID,
            "user2": likedUserID,
            "timestamp": Timestamp()
        ]

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

        guard currentIndex < users.count else {
            return
        }

        let skippedUser = users[currentIndex]

        guard let skippedUserID = skippedUser.id else {
            print("Error: Skipped user does not have an ID")
            return
        }

        moveToNextUser()

        interactedUsers.insert(skippedUserID)
        saveInteractedUsers()
    }

    private func moveToNextUser() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.interactionResult = nil

            self.currentIndex += 1

            if self.currentIndex >= self.users.count {
                self.currentIndex = 0
                self.users.removeAll()
            }

            UserDefaults.standard.set(self.currentIndex, forKey: "currentIndex")
        }
    }

    private func saveInteractedUsers() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(currentUserID)

        userRef.updateData([
            "interactedUsers": Array(interactedUsers)
        ]) { error in
            if let error = error {
                print("Error saving interacted users: \(error.localizedDescription)")
            } else {
                print("Interacted users saved successfully.")
            }
        }
        
        UserDefaults.standard.set(Array(interactedUsers), forKey: "interactedUsers_\(currentUserID)")
    }

    private func loadInteractedUsers(completion: @escaping (Bool) -> Void) {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Error: User not authenticated")
            completion(false)
            return
        }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(currentUserID)

        if let savedInteractedUsers = UserDefaults.standard.array(forKey: "interactedUsers_\(currentUserID)") as? [String] {
            self.interactedUsers = Set(savedInteractedUsers)
            completion(true)
            return
        }

        userRef.getDocument { document, error in
            if let document = document, document.exists {
                if let interacted = document.data()?["interactedUsers"] as? [String] {
                    self.interactedUsers = Set(interacted)
                }
                UserDefaults.standard.set(Array(self.interactedUsers), forKey: "interactedUsers_\(currentUserID)")
                completion(true)
            } else {
                print("Error loading interacted users: \(error?.localizedDescription ?? "Unknown error")")
                completion(false)
            }
        }
    }

    private func deleteMedia(at index: Int) {
        guard currentIndex < users.count else { return }
        if let mediaItems = users[currentIndex].mediaItems {
            users[currentIndex].mediaItems?.remove(at: index)
        } else {
            print("No media items to delete.")
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
                                    .foregroundColor(.black)
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

import SwiftUI
import AVKit
import Kingfisher

struct UserCardView: View {
    var user: UserProfile
    var newMedia: [MediaItem] = []
    @State private var currentMediaIndex = 0
    @State private var shownUserIDs: Set<String> = []

    private var allMediaItems: [MediaItem] {
        let mediaItems = user.mediaItems ?? []
        return mediaItems + newMedia
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                TabView(selection: $currentMediaIndex) {
                    ForEach(allMediaItems.indices, id: \.self) { index in
                        let mediaItem = allMediaItems[index]
                        ZStack {
                            if mediaItem.type == .video {
                                VideoPlayerView(url: mediaItem.url)
                                    .cornerRadius(20)
                                    .padding(.horizontal, 10)
                                    .tag(index)
                            } else {
                                KFImage(mediaItem.url)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.5)
                                    .clipped()
                                    .cornerRadius(20)
                                    .tag(index)
                            }
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                .frame(height: UIScreen.main.bounds.height * 0.5)
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
            .background(Color.white.opacity(0.8))
            .cornerRadius(20)
            .padding(.top, 5)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.6))
        )
        .padding()
    }
}

import SwiftUI
import AVKit

struct VideoPlayerView: View {
    var url: URL
    @State private var player: AVPlayer?

    var body: some View {
        GeometryReader { geometry in
            VideoPlayer(player: player)
                .onAppear {
                    player = AVPlayer(url: url)
                }
                .onDisappear {
                    player?.pause()
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .aspectRatio(contentMode: .fit)
                .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 2))
        .shadow(radius: 5)
    }
}

