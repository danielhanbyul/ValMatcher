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
    @EnvironmentObject var appState: AppState  // Access the shared app state]
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
    @State private var isInChatView = false
     
    // Added States
    @State private var interactedUsers: Set<String> = []
    @State private var lastRefreshDate: Date? = nil
    @State private var shownUserIDs: Set<String> = []
    @State private var currentChatID: String? = nil
    @State private var unreadMessagesListener: ListenerRegistration?
    @State private var unreadCountUser1 = 0
    @State private var unreadCountUser2 = 0
    @State private var isUnreadMessagesListenerActive = false
    






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
                listenForUnreadMessages()
                self.interactedUsers.removeAll()
                loadInteractedUsers { success in
                    if success {
                        fetchAllUsers()
                    }
                }
                fetchUnreadMessagesCount()
                listenForUserDeletions()
            }
            NotificationCenter.default.addObserver(forName: Notification.Name("EnterChatView"), object: nil, queue: .main) { notification in
                if let matchID = notification.object as? String {
                    print("DEBUG: Received EnterChatView notification for matchID: \(matchID)")
                    self.currentChatID = matchID
                    self.isInChatView = true
                    print("DEBUG: isInChatView set to true, currentChatID set to \(matchID)")
                }
            }
            NotificationCenter.default.addObserver(forName: Notification.Name("ExitChatView"), object: nil, queue: .main) { notification in
                print("DEBUG: Received ExitChatView notification")
                self.currentChatID = nil
                self.isInChatView = false
                print("DEBUG: isInChatView set to false, currentChatID reset to nil")
            }
        }

    }
    
    
    // Listen for deletions in Firestore and remove the corresponding user from `users`
        private func listenForUserDeletions() {
            let db = Firestore.firestore()
            
            db.collection("users").addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening for deletions: \(error.localizedDescription)")
                    return
                }
                
                snapshot?.documentChanges.forEach { change in
                    if change.type == .removed {
                        if let deletedUser = try? change.document.data(as: UserProfile.self), let userID = deletedUser.id {
                            self.removeUserFromList(userID: userID)
                        }
                    }
                }
            }
        }
    
    private func removeUserFromList(userID: String) {
            if let index = self.users.firstIndex(where: { $0.id == userID }) {
                self.users.remove(at: index)
                print("User \(userID) removed from users list.")
            }
        }
    
    private func clearLocalUserData() {
            guard let currentUserID = Auth.auth().currentUser?.uid else { return }

            // Clear UserDefaults for stored users if necessary
            UserDefaults.standard.removeObject(forKey: "interactedUsers_\(currentUserID)")
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

        // This filters out users who have been interacted with (liked or passed)
        let nonInteractedUsers = self.users.filter { user in
            guard let userID = user.id else { return false }
            return !self.interactedUsers.contains(userID)
        }

        // Now update the users array to only show non-interacted users
        self.users = nonInteractedUsers
    }

    private var userInfoView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Show only the profile questions answered by the user
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

        // Set up a listener for new users being added
        db.collection("users").addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error listening for new users: \(error.localizedDescription)")
                return
            }

            snapshot?.documentChanges.forEach { change in
                if change.type == .added {
                    if let newUser = try? change.document.data(as: UserProfile.self) {
                        guard let newUserID = newUser.id, newUserID != currentUserID else { return }

                        // Add this check to ensure the user is not interacted with or already shown
                        if !self.interactedUsers.contains(newUserID) && !self.shownUserIDs.contains(newUserID) {
                            self.users.append(newUser)
                            self.shownUserIDs.insert(newUserID)  // Add the new user's ID to the set to prevent future duplicates
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

        // Define the cutoff date as October 29, 2024, at 12:00 PM UTC
        var dateComponents = DateComponents()
        dateComponents.year = 2024
        dateComponents.month = 10
        dateComponents.day = 28
        dateComponents.hour = 12
        dateComponents.minute = 0
        dateComponents.timeZone = TimeZone(secondsFromGMT: 0)  // Use UTC time zone

        let calendar = Calendar.current
        guard let specificDate = calendar.date(from: dateComponents) else {
            print("Error: Failed to create the specified cutoff date.")
            return
        }
        
        let cutoffDate = Timestamp(date: specificDate)
        print("DEBUG: Using cutoff date \(cutoffDate.dateValue()) for filtering users")

        db.collection("users")
            .whereField("createdAt", isGreaterThan: cutoffDate)  // Fetch users created after the cutoff date
            .getDocuments(source: .server) { (querySnapshot, error) in  // Force fetch from server to avoid caching issues
                if let error = error {
                    print("Error fetching users: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    print("No documents found after applying date filter.")
                    return
                }
                
                print("DEBUG: Total documents fetched: \(documents.count)")

                let fetchedUsers = documents.compactMap { document in
                    let userData = try? document.data(as: UserProfile.self)
                    
                    if let userData = userData, let createdAt = document.data()["createdAt"] as? Timestamp {
                        print("DEBUG: User \(userData.id ?? "Unknown ID") createdAt: \(createdAt.dateValue())")
                    }
                    
                    return userData
                }
                
                // Apply additional filtering to exclude the current user, interacted users, and already shown users
                self.users = fetchedUsers.filter { user in
                    guard let userID = user.id else { return false }
                    return userID != currentUserID &&
                           !self.interactedUsers.contains(userID) &&
                           !self.shownUserIDs.contains(userID)
                }

                print("DEBUG: Filtered users count (excluding current user and interacted users): \(self.users.count)")
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

    private func fetchUnreadMessagesCount() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let matchesRef = db.collection("matches")
        
        var totalUnreadCount = 0
        let group = DispatchGroup()
        
        let queries = [
            matchesRef.whereField("user1", isEqualTo: currentUserID),
            matchesRef.whereField("user2", isEqualTo: currentUserID)
        ]
        
        for query in queries {
            group.enter()
            query.getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching matches: \(error)")
                    group.leave()
                    return
                }
                
                let matches = snapshot?.documents ?? []
                let innerGroup = DispatchGroup()
                
                for document in matches {
                    innerGroup.enter()
                    let matchID = document.documentID
                    self.fetchUnreadMessagesCountForMatch(matchID: matchID, currentUserID: currentUserID) { unreadCount in
                        totalUnreadCount += unreadCount
                        innerGroup.leave()
                    }
                }
                
                innerGroup.notify(queue: .main) {
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            self.unreadMessagesCount = totalUnreadCount
        }
    }
    
    func listenForUnreadMessages() {
        print("DEBUG: listenForUnreadMessages called")
        
        guard !isUnreadMessagesListenerActive else { return }
        isUnreadMessagesListenerActive = true
        
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Remove any existing listener to prevent duplicates
        self.unreadMessagesListener?.remove()
        
        var listeners: [ListenerRegistration] = []
        
        // Listener for matches where currentUserID is user1
        let listener1 = db.collection("matches")
            .whereField("user1", isEqualTo: currentUserID)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("DEBUG: Error listening for matches (user1): \(error.localizedDescription)")
                    return
                }
                print("DEBUG: appState.isInChatView = \(appState.isInChatView), currentChatID = \(appState.currentChatID ?? "None")")
                
                snapshot?.documentChanges.forEach { change in
                    let matchID = change.document.documentID
                    if appState.isInChatView && matchID == appState.currentChatID {
                        print("DEBUG: Skipping unread message updates for current chat \(matchID)")
                    } else {
                        // Process updates for other chats
                        self.processSnapshot(snapshot: snapshot, currentUserID: currentUserID, isUser1: true)
                        
                        // Send push notification if app is in background
                        if UIApplication.shared.applicationState != .active {
                            self.sendPushNotification(for: matchID)
                        }
                    }
                }
            }
        listeners.append(listener1)
        
        // Listener for matches where currentUserID is user2
        let listener2 = db.collection("matches")
            .whereField("user2", isEqualTo: currentUserID)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("DEBUG: Error listening for matches (user2): \(error.localizedDescription)")
                    return
                }
                print("DEBUG: appState.isInChatView = \(appState.isInChatView), currentChatID = \(appState.currentChatID ?? "None")")
                
                snapshot?.documentChanges.forEach { change in
                    let matchID = change.document.documentID
                    if appState.isInChatView && matchID == appState.currentChatID {
                        print("DEBUG: Skipping unread message updates for current chat \(matchID)")
                    } else {
                        self.processSnapshot(snapshot: snapshot, currentUserID: currentUserID, isUser1: false)
                        
                        // Send push notification if app is in background
                        if UIApplication.shared.applicationState != .active {
                            self.sendPushNotification(for: matchID)
                        }
                    }
                }
            }
        listeners.append(listener2)
        
        // Keep track of the listeners to remove them later if needed
        self.unreadMessagesListener = ListenerRegistrationGroup(listeners: listeners)
    }
    
    private func sendPushNotification(for matchID: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        // Fetch the most recent message from Firestore for this chat
        let db = Firestore.firestore()
        db.collection("matches").document(matchID).collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching latest message: \(error.localizedDescription)")
                    return
                }

                guard let document = snapshot?.documents.first else { return }
                let data = document.data()
                let messageText = data["content"] as? String ?? "New message"
                let senderName = data["senderName"] as? String ?? "Someone"

                // Trigger a push notification
                let title = "New Message from \(senderName)"
                let body = messageText

                // Create the notification content
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default

                // Send the notification via APNs
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request)
            }
    }




    func processSnapshot(snapshot: QuerySnapshot?, currentUserID: String, isUser1: Bool) {
        guard let documents = snapshot?.documents else { return }
        
        var totalUnreadCount = 0
        let group = DispatchGroup()
        
        for document in documents {
            let matchID = document.documentID
            
            if matchID == self.currentChatID {
                print("DEBUG: Skipping matchID \(matchID) because it is the currentChatID")
                continue
            }
            
            group.enter()
            self.fetchUnreadMessagesCountForMatch(matchID: matchID, currentUserID: currentUserID) { unreadCount in
                print("DEBUG: Unread messages for matchID \(matchID): \(unreadCount)")
                totalUnreadCount += unreadCount
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if isUser1 {
                self.unreadCountUser1 = totalUnreadCount
            } else {
                self.unreadCountUser2 = totalUnreadCount
            }

            let totalUnreadMessages = self.unreadCountUser1 + self.unreadCountUser2
            
            // Modify to use self.currentChatID instead of matchID
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Skip update if user is still in any chat (i.e., self.currentChatID is not nil)
                if self.isInChatView {
                    print("DEBUG: Preventing unreadMessagesCount update while in ChatView.")
                    return
                }
                
                self.unreadMessagesCount = totalUnreadMessages
                print("DEBUG: Updating unreadMessagesCount to \(totalUnreadMessages)")
            }
        }
    }



    // Custom class to handle multiple listeners
    class ListenerRegistrationGroup: NSObject, ListenerRegistration {
        var listeners: [ListenerRegistration]
        
        init(listeners: [ListenerRegistration]) {
            self.listeners = listeners
        }
        
        func remove() {
            for listener in listeners {
                listener.remove()
            }
        }
    }



    private func fetchUnreadMessagesCountForMatch(matchID: String, currentUserID: String, completion: @escaping (Int) -> Void) {
        if matchID == self.currentChatID {
            print("DEBUG: Skipping fetchUnreadMessagesCountForMatch for matchID \(matchID) because it is the currentChatID")
            completion(0)
            return
        }
        let db = Firestore.firestore()
        db.collection("matches").document(matchID).collection("messages")
            .whereField("senderID", isNotEqualTo: currentUserID)
            .whereField("isRead", isEqualTo: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching unread messages: \(error)")
                    completion(0)
                    return
                }
                
                let unreadCount = snapshot?.documents.count ?? 0
                print("DEBUG: Fetched \(unreadCount) unread messages for matchID \(matchID)")
                completion(unreadCount)
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

        // System notification
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
                }

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

        // DEBUG: Log current user and liked user information
        print("DEBUG: Attempting to create match")
        print("DEBUG: CurrentUserID: \(currentUserID), CurrentUserName: \(self.userProfileViewModel.user.name)")
        print("DEBUG: LikedUserID: \(likedUserID), LikedUserName: \(likedUser.name)")

        // Check if a match already exists between the two users
        db.collection("matches")
            .whereField("user1", in: [currentUserID, likedUserID])
            .whereField("user2", in: [currentUserID, likedUserID])
            .getDocuments { querySnapshot, error in
                if let error = error {
                    print("Error checking existing match: \(error.localizedDescription)")
                    return
                }

                // If no existing match, create the match and notify both users
                if querySnapshot?.documents.isEmpty == true {
                    db.collection("matches").addDocument(data: matchData) { error in
                        if let error = error {
                            print("Error creating match: \(error.localizedDescription)")
                        } else {
                            print("Match created successfully between \(currentUserID) and \(likedUserID)")

                            // Validate that userProfileViewModel.user.name is not empty
                            guard !self.userProfileViewModel.user.name.isEmpty else {
                                print("DEBUG: Current user's name is empty. Notification will not be sent.")
                                return
                            }

                            // Validate that likedUserID is not empty
                            guard !likedUserID.isEmpty else {
                                print("DEBUG: likedUserID is empty. Notification will not be sent.")
                                return
                            }

                            // Notify both users
                            self.sendMatchNotification(
                                to: currentUserID,
                                matchedUserName: likedUser.name
                            )
                            self.sendMatchNotification(
                                to: likedUserID,
                                matchedUserName: self.userProfileViewModel.user.name
                            )

                            // Create the chat between the two users
                            self.createDMChat(
                                currentUserID: currentUserID,
                                likedUserID: likedUserID,
                                likedUser: likedUser
                            )
                        }
                    }
                } else {
                    print("DEBUG: Match already exists between \(currentUserID) and \(likedUserID)")
                }
            }
    }


    private func sendMatchNotification(to userID: String, matchedUserName: String) {
        // Send the notification to Firestore
        let db = Firestore.firestore()
        let notificationMessage = "You matched with \(matchedUserName)!"

        let notificationData: [String: Any] = [
            "userID": userID,
            "message": notificationMessage,
            "timestamp": Timestamp()
        ]

        db.collection("notifications").addDocument(data: notificationData) { error in
            if let error = error {
                print("Error sending notification: \(error.localizedDescription)")
            } else {
                print("Notification sent successfully to userID: \(userID)")
            }
        }

        // If the notification is for the currently logged-in user, display it immediately
        if Auth.auth().currentUser?.uid == userID {
            DispatchQueue.main.async {
                self.alertMessage = notificationMessage
                self.showAlert = true
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
                print("Notification sent successfully to userID: \(userID)")
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
