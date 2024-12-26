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
    @EnvironmentObject var appState: AppState  // Access the shared app state
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
    @State private var processedMatchIDs: Set<String> = []
    @State private var showInAppMatchNotification = false
    @State private var inAppNotificationMessage = ""

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

            if showInAppMatchNotification {
                ZStack {
                    // Dimmed background to prevent interaction with the app
                    Color.black.opacity(0.7)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            // Prevent dismissing by tapping outside
                        }

                    VStack(spacing: 20) {
                        // Icon and Header
                        HStack(spacing: 12) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 45, weight: .medium))
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("It's a Match!")
                                    .font(.custom("AvenirNext-DemiBold", size: 28)) // Cleaner font style
                                    .foregroundColor(.white)

                                Text(inAppNotificationMessage)
                                    .font(.custom("AvenirNext-Regular", size: 16)) // Softer and more elegant
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.leading)
                            }
                        }

                        Divider()
                            .background(Color.white.opacity(0.5))

                        // Dismiss Button
                        Button(action: {
                            withAnimation {
                                self.showInAppMatchNotification = false // Dismiss the notification
                            }
                        }) {
                            Text("Dismiss")
                                .font(.custom("AvenirNext-DemiBold", size: 16)) // Consistent button styling
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 40)
                                .background(Color.green.opacity(0.9))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.02, green: 0.18, blue: 0.15),
                                Color(red: 0.21, green: 0.29, blue: 0.40)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 5)
                    .padding(.horizontal, 30)
                    .transition(.scale)
                    .animation(.easeInOut(duration: 0.3), value: showInAppMatchNotification)
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
//                    NavigationLink(destination: NotificationsView(notifications: $notifications, notificationCount: $notificationCount)) {
//                        Image(systemName: "bell.fill")
//                            .foregroundColor(.white)
//                            .imageScale(.medium)
//                            .overlay(
//                                BadgeView(count: notificationCount)
//                                    .offset(x: 12, y: -12)
//                            )
//                    }
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
            Alert(
                title: Text("Match Found!"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    acknowledgedNotifications.insert(alertMessage)
                }
            )
        }
        .onAppear {
            if isSignedIn {
                listenForNewMatches(currentUserID: Auth.auth().currentUser?.uid ?? "")
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
    

    private func listenForMatchNotifications() {
        NotificationCenter.default.addObserver(forName: Notification.Name("MatchCreated"), object: nil, queue: .main) { notification in
            if let message = notification.object as? String {
                self.alertMessage = message
                self.showAlert = true
            }
        }
        
    
    }


    
    
    // Listen for deletions in Firestore and remove the corresponding user from users
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
        dateComponents.month = 12
        dateComponents.day = 26
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
        let matchesRef = db.collection("matches")

        let userPair = [currentUserID, likedUserID]

        matchesRef
            .whereField("user1", in: userPair)
            .whereField("user2", in: userPair)
            .getDocuments { (snapshot, error) in
                if let error = error {
                    print("Error checking existing match: \(error.localizedDescription)")
                    return
                }

                var matchExists = false
                snapshot?.documents.forEach { doc in
                    let data = doc.data()
                    let user1 = data["user1"] as? String ?? ""
                    let user2 = data["user2"] as? String ?? ""
                    if (user1 == currentUserID && user2 == likedUserID) ||
                       (user1 == likedUserID && user2 == currentUserID) {
                        matchExists = true
                    }
                }

                if !matchExists {
                    let matchData: [String: Any] = [
                        "user1": currentUserID,
                        "user2": likedUserID,
                        "notificationsSent": [
                            currentUserID: false,
                            likedUserID: false
                        ],
                        "timestamp": Timestamp()
                    ]

                    matchesRef.addDocument(data: matchData) { error in
                        if let error = error {
                            print("Error creating match: \(error.localizedDescription)")
                        } else {
                            print("Match document created successfully.")
                        }
                    }
                } else {
                    print("DEBUG: Match already exists between \(currentUserID) and \(likedUserID).")
                }
            }
    }



    
    private func listenForNewMatches(currentUserID: String) {
        let db = Firestore.firestore()

        // Listen for matches where the current user is user1
        db.collection("matches")
          .whereField("user1", isEqualTo: currentUserID)
          .addSnapshotListener { snapshot, error in
              if let error = error {
                  print("Error listening for matches (user1): \(error.localizedDescription)")
                  return
              }
              self.handleMatchChanges(snapshot: snapshot, currentUserID: currentUserID)
          }
        
        // Listen for matches where the current user is user2
        db.collection("matches")
          .whereField("user2", isEqualTo: currentUserID)
          .addSnapshotListener { snapshot, error in
              if let error = error {
                  print("Error listening for matches (user2): \(error.localizedDescription)")
                  return
              }
              self.handleMatchChanges(snapshot: snapshot, currentUserID: currentUserID)
          }
    }

    private func handleMatchChanges(snapshot: QuerySnapshot?, currentUserID: String) {
        guard let snapshot = snapshot else { return }

        for change in snapshot.documentChanges {
            if change.type == .added {
                let matchID = change.document.documentID
                if processedMatchIDs.contains(matchID) {
                    continue  // Skip already processed matches
                }
                processedMatchIDs.insert(matchID)

                let matchData = change.document.data()
                let user1 = matchData["user1"] as? String ?? ""
                let user2 = matchData["user2"] as? String ?? ""

                // Determine the other user's ID
                let otherUserID = user1 == currentUserID ? user2 : user1

                // Check notificationsSent status
                if let notificationsSent = matchData["notificationsSent"] as? [String: Bool],
                   notificationsSent[currentUserID] == true {
                    continue  // Skip if the current user was already notified
                }

                // Update notificationsSent field in Firestore to avoid duplicate notifications
                var updatedNotificationsSent = matchData["notificationsSent"] as? [String: Bool] ?? [:]
                updatedNotificationsSent[currentUserID] = true

                let db = Firestore.firestore()
                db.collection("matches").document(matchID).updateData(["notificationsSent": updatedNotificationsSent]) { error in
                    if let error = error {
                        print("ERROR: Failed to update notificationsSent for match \(matchID): \(error.localizedDescription)")
                    }
                }

                // Fetch the name of the other user and show a single in-app notification
                fetchUserName(userID: otherUserID) { userName in
                    let message = "You matched with \(userName)!"
                    self.showInAppMatchNotification(message: message) // Use the in-app notification
                }
            }
        }
    }

    // In-App Notification Logic (Centralized)
    private func showInAppMatchNotification(message: String) {
        self.inAppNotificationMessage = message
        self.showInAppMatchNotification = true
    }


    private func recordMatchNotification(message: String) {
        // Record the match in notifications
        DispatchQueue.main.async {
            self.notifications.append(message)
            self.notificationCount += 1
            print("DEBUG: Match notification recorded: \(message)")
        }

        // Show in-app notification if the user is active
        if UIApplication.shared.applicationState == .active {
            self.bannerMessage = message
            self.showNotificationBanner = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self.showNotificationBanner = false
            }
        }
    }


    private func showInAppNotification(message: String) {
        self.bannerMessage = message
        self.showNotificationBanner = true
        
        // Automatically hide the banner after a few seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showNotificationBanner = false
        }
    }



    /// Example function to fetch the other user's name and show the local match notification
    private func fetchUserNameAndNotify(matchData: [String: Any], currentUserID: String) {
        let user1 = matchData["user1"] as? String ?? ""
        let user2 = matchData["user2"] as? String ?? ""
        let otherUserID = (user1 == currentUserID) ? user2 : user1
        
        fetchUserName(userID: otherUserID) { userName in
            let message = "You matched with \(userName)!"
            // Show local UI alert or push notification here
            self.appState.alertMessage = message
            self.appState.showAlert = true
            print("DEBUG: Match notification shown: \(message)")
        }
    }

    private func fetchUserName(userID: String, completion: @escaping (String) -> Void) {
        let db = Firestore.firestore()
        db.collection("users").document(userID).getDocument { document, error in
            if let error = error {
                print("Error fetching user name: \(error.localizedDescription)")
                completion("Unknown")
                return
            }
            if let data = document?.data() {
                let name = data["name"] as? String ?? "Unknown"
                completion(name)
            } else {
                completion("Unknown")
            }
        }
    }


    
    private func showMatchNotification(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Match Found!"
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing local notification: \(error.localizedDescription)")
            }
        }
    }
    
    




    private func sendMatchNotification(to userID: String, matchedUserName: String) {
        let db = Firestore.firestore()
        db.collection("users").document(userID).getDocument { document, error in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                return
            }

            guard let document = document, document.exists, let data = document.data() else {
                print("User document does not exist")
                return
            }

            if let fcmToken = data["fcmToken"] as? String, !fcmToken.isEmpty {
                let message = "\(matchedUserName) has matched with you!"
                self.sendPushNotification(to: fcmToken, title: "It's a Match!", body: message)
            } else {
                print("No FCM token found for user \(userID)")
            }
        }
    }


    private func sendPushNotification(to fcmToken: String, title: String, body: String) {
        let urlString = "https://fcm.googleapis.com/fcm/send"
        let url = URL(string: urlString)!
        let serverKey = "AIzaSyA-Eew48TEhrZnX80C8lyYcKkuYRx0hNME"  // Replace with your actual FCM server key

        let notification: [String: Any] = [
            "to": fcmToken,
            "notification": [
                "title": title,
                "body": body,
                "sound": "default"
            ],
            "data": [
                "match": "yes"
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("key=\(serverKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: notification, options: [])

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending push notification: \(error.localizedDescription)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                print("Push notification HTTP response status code: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    print("Push notification failed with status code: \(httpResponse.statusCode)")
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("Response data: \(responseString)")
                    }
                } else {
                    print("Push notification sent successfully to token: \(fcmToken)")
                }
            }
        }
        task.resume()
    }
    
    


    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("DEBUG: Notification tapped. UserInfo: \(userInfo)")

        if let match = userInfo["match"] as? String, match == "yes" {
            // Handle match notification tap
            print("DEBUG: Match notification tapped.")
            // You can navigate to a specific view or perform an action here
        }

        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("DEBUG: Received notification in foreground: \(notification.request.content.userInfo)")

        if let match = notification.request.content.userInfo["match"] as? String, match == "yes" {
            // Handle match notification received while app is in foreground
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.badge, .sound, .banner])
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
