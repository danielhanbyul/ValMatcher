//
//  ContentView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/6/24.
//
import SwiftUI
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

    // Existing states
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

    // Additional states
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

    // New: to ensure the feed only loads once
    @State private var isDataLoaded = false
    @State private var userListener: ListenerRegistration?
    @State private var selectedVideoURL: IdentifiableURL?
    


    enum InteractionResult {
        case liked
        case passed
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.02, green: 0.18, blue: 0.15),
                    Color(red: 0.21, green: 0.29, blue: 0.40)
                ]),
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
                    Color.black.opacity(0.7)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            // Prevent dismissing by tapping outside
                        }

                    VStack(spacing: 20) {
                        HStack(spacing: 12) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 45, weight: .medium))
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("It's a Match!")
                                    .font(.custom("AvenirNext-DemiBold", size: 28))
                                    .foregroundColor(.white)

                                Text(inAppNotificationMessage)
                                    .font(.custom("AvenirNext-Regular", size: 16))
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.leading)
                            }
                        }

                        Divider()
                            .background(Color.white.opacity(0.5))

                        Button(action: {
                            withAnimation {
                                self.showInAppMatchNotification = false
                            }
                        }) {
                            Text("Dismiss")
                                .font(.custom("AvenirNext-DemiBold", size: 16))
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
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.top, 10)
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                HStack(spacing: 15) {
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

                // First load "interactedUsers", then fetch all users and set up listener
                loadInteractedUsers { success in
                    if success {
                        fetchAllUsers {
                            // After fetching all users, set up the real-time listener
                            if !isDataLoaded {
                                isDataLoaded = true
                                setUpUserFeedListener()
                            }
                        }
                    }
                }

                fetchUnreadMessagesCount()
                listenForUserDeletions()
            }


            // Observers for chat transitions
            NotificationCenter.default.addObserver(
                forName: Notification.Name("EnterChatView"),
                object: nil,
                queue: .main
            ) { notification in
                if let matchID = notification.object as? String {
                    print("DEBUG: Received EnterChatView notification for matchID: \(matchID)")
                    self.currentChatID = matchID
                    self.isInChatView = true
                    print("DEBUG: isInChatView set to true, currentChatID set to \(matchID)")
                }
            }
            NotificationCenter.default.addObserver(
                forName: Notification.Name("ExitChatView"),
                object: nil,
                queue: .main
            ) { notification in
                print("DEBUG: Received ExitChatView notification")
                self.currentChatID = nil
                self.isInChatView = false
                print("DEBUG: isInChatView set to false, currentChatID reset to nil")
            }
        }
    }
    
    

    private func setUpUserFeedListener() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()

        userListener = db.collection("users")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("DEBUG: Error listening for user feed: \(error.localizedDescription).")
                    return
                }
                guard let snapshot = snapshot else { return }

                var addedUsers = [UserProfile]()
                var removedUserIDs = [String]()

                snapshot.documentChanges.forEach { change in
                    guard let updatedUser = try? change.document.data(as: UserProfile.self),
                          let updatedUserID = updatedUser.id else {
                        print("DEBUG: Failed to parse user doc \(change.document.documentID).")
                        return
                    }

                    // Skip if this doc belongs to me (on my device)
                    if updatedUserID == currentUserID {
                        print("DEBUG: Skipping my own doc: \(updatedUserID)")
                        return
                    }

                    switch change.type {
                    case .added:
                        if !self.interactedUsers.contains(updatedUserID) {
                            print("DEBUG: [Feed] Adding user \(updatedUserID).")
                            addedUsers.append(updatedUser)
                        }
                    case .modified:
                        // If this user is currently being viewed, skip updates
                        if currentIndex < users.count,
                           users[currentIndex].id == updatedUserID {
                            print("DEBUG: Ignoring modifications for user currently on screen.")
                            return
                        }

                        // Update the user in the list or re-add them if necessary
                        if let index = self.users.firstIndex(where: { $0.id == updatedUserID }) {
                            self.users[index] = updatedUser
                        } else if !self.interactedUsers.contains(updatedUserID) {
                            print("DEBUG: Re-adding updated user \(updatedUserID).")
                            self.users.append(updatedUser)
                        }

                    case .removed:
                        print("DEBUG: [Feed] Removing user \(updatedUserID).")
                        removedUserIDs.append(updatedUserID)
                    default:
                        break
                    }
                }

                // Append or remove users as necessary
                if !addedUsers.isEmpty {
                    self.users.append(contentsOf: addedUsers)
                }
                if !removedUserIDs.isEmpty {
                    self.users.removeAll { removedUserIDs.contains($0.id ?? "") }
                }

                // Sort users
                self.users.sort(by: {
                    ($0.createdAt?.dateValue() ?? Date()) < ($1.createdAt?.dateValue() ?? Date())
                })

                print("DEBUG: [Feed] Final user list count: \(self.users.count).")
            }
    }

    
    



    
    private func isCurrentUser(_ userID: String) -> Bool {
        // Compare userID to the currently authenticated user’s ID
        guard let currentUser = Auth.auth().currentUser else {
            return false
        }
        return userID == currentUser.uid
    }


    
    private func updateProfileInFirestore() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(currentUserID)

        userRef.updateData([
            "lastUpdated": Timestamp()
        ]) { error in
            if let error = error {
                print("DEBUG: Error updating profile: \(error.localizedDescription)")
            } else {
                print("DEBUG: Profile updated successfully with new timestamp.")
            }
        }
    }





    func markUserAsInteracted(userID: String, interactionType: String) {
        // Validate the user ID
        guard !userID.isEmpty else {
            print("DEBUG: Attempted to mark an invalid or empty user ID as interacted.")
            return
        }

        // Check if the user is already marked as interacted
        if interactedUsers.contains(userID) {
            print("DEBUG: User \(userID) is already marked as interacted. Skipping.")
            return
        }

        // Log the specific interaction type (e.g., "swiped left" or "liked")
        print("DEBUG: Marking user \(userID) as interacted due to \(interactionType).")

        // Add the user to the interactedUsers set
        interactedUsers.insert(userID)

        // Save the updated set locally and remotely
        saveInteractedUsers()

        // Remove the user from the current list of users in ContentView
        if let index = users.firstIndex(where: { $0.id == userID }) {
            users.remove(at: index)
        }
    }



    private var filteredUsers: [UserProfile] {
        users.filter {
            !interactedUsers.contains($0.id ?? "") &&
            $0.id != Auth.auth().currentUser?.uid &&
//            $0.hasAnsweredQuestions &&
            !$0.name.isEmpty
        }
    }

    private func loadInteractedUsers(completion: @escaping (Bool) -> Void) {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("DEBUG: Error: User not authenticated")
            completion(false)
            return
        }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(currentUserID)

        print("DEBUG: Loading interactedUsers for user \(currentUserID)")

        if let savedInteractedUsers = UserDefaults.standard.array(forKey: "interactedUsers_\(currentUserID)") as? [String] {
            self.interactedUsers = Set(savedInteractedUsers)
            print("DEBUG: Interacted users loaded from UserDefaults: \(Array(interactedUsers))")
            completion(true)
            return
        }

        userRef.getDocument { document, error in
            if let document = document, document.exists {
                if let interacted = document.data()?["interactedUsers"] as? [String] {
                    self.interactedUsers = Set(interacted)
                    print("DEBUG: Interacted users loaded from Firestore: \(Array(self.interactedUsers))")
                }
                UserDefaults.standard.set(Array(self.interactedUsers), forKey: "interactedUsers_\(currentUserID)")
                completion(true)
            } else {
                print("DEBUG: Error loading interacted users from Firestore: \(error?.localizedDescription ?? "Unknown error")")
                completion(false)
            }
        }
    }

    private func saveInteractedUsers() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(currentUserID)

        print("DEBUG: Saving interactedUsers: \(Array(interactedUsers))")

        userRef.updateData([
            "interactedUsers": Array(interactedUsers)
        ]) { error in
            if let error = error {
                print("DEBUG: Error saving interacted users: \(error.localizedDescription)")
            } else {
                print("DEBUG: Interacted users saved successfully.")
            }
        }

        UserDefaults.standard.set(Array(interactedUsers), forKey: "interactedUsers_\(currentUserID)")
        print("DEBUG: Interacted users saved locally to UserDefaults.")
    }

    /// Keeps new users sorted ascending by createdAt
    private func insertUserInAscendingOrder(_ newUser: UserProfile) {
        guard let newCreatedAt = newUser.createdAt else {
            self.users.append(newUser)
            return
        }
        var insertionIndex = self.users.count
        for (index, existingUser) in self.users.enumerated() {
            guard let existingCreatedAt = existingUser.createdAt else { continue }
            if newCreatedAt.compare(existingCreatedAt) == .orderedAscending {
                insertionIndex = index
                break
            }
        }
        self.users.insert(newUser, at: insertionIndex)
    }

    // MARK: - UI for user card stack
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
                    
                    if let result = interactionResult {
                        interactionResultView(result)
                    }
                }
            }
            .padding([.horizontal, .bottom])

            // Show user information
            userInfoView
                .padding(.horizontal)

            // Display media for the current user
            if currentIndex < users.count, let mediaItems = users[currentIndex].mediaItems {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(mediaItems, id: \.url) { media in
                            mediaThumbnailView(for: media)
                                .frame(width: UIScreen.main.bounds.width - 40, height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(.vertical, 5)
                                .onTapGesture {
                                    // Enable fullscreen playback when tapped
                                    if media.type == .video {
                                        selectedVideoURL = IdentifiableURL(url: media.url)
                                    }
                                }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    
    // Media thumbnails for preview
    private func mediaThumbnailView(for media: MediaItem) -> some View {
        Group {
            if media.type == .image {
                KFImage(media.url)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if media.type == .video {
                FeedVideoPlayerView(url: media.url)
            } else {
                EmptyView()
            }
        }
    }

    
    struct FeedVideoPlayerView: View {
        let url: URL
        @State private var player = AVPlayer()
        @State private var isHorizontal = false
        @State private var showFullScreenPlayer = false

        init(url: URL) {
            self.url = url
            _player = State(initialValue: AVPlayer(url: url))
        }

        var body: some View {
            ZStack {
                GeometryReader { geo in
                    VideoPlayer(player: player)
                        .onAppear {
                            checkOrientation()
                            player.seek(to: .zero)
                            player.play()
                            addReplayObserver()
                        }
                        .onTapGesture {
                            // If horizontal => open fullscreen
                            if isHorizontal {
                                showFullScreenPlayer = true
                            } else {
                                // Vertical => toggle play/pause
                                if player.timeControlStatus == .playing {
                                    player.pause()
                                } else {
                                    player.play()
                                }
                            }
                        }
                }
            }
            .frame(width: 100, height: 100) // or whatever size in your feed
            .clipShape(RoundedRectangle(cornerRadius: 10))
            // Fullscreen
            .fullScreenCover(isPresented: $showFullScreenPlayer) {
                FullScreenVideoPlayer(url: url, isHorizontalVideo: isHorizontal)
            }
        }

        private func checkOrientation() {
            let asset = AVAsset(url: url)
            guard let track = asset.tracks(withMediaType: .video).first else { return }
            let dims = track.naturalSize.applying(track.preferredTransform)
            isHorizontal = abs(dims.width) > abs(dims.height)
        }

        private func addReplayObserver() {
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { _ in
                player.seek(to: .zero)
                player.play()
            }
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
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                    .animation(.easeInOut, value: result)
            } else if result == .passed {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.red)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                    .animation(.easeInOut, value: result)
            }
        }
        .zIndex(1) // Ensure this view is on top
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

    private func handleInteractions() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        print("DEBUG: Current interactedUsers: \(Array(interactedUsers))")
        print("DEBUG: Total users before filtering: \(users.count)")

        // Filter out users who have been interacted with
        let nonInteractedUsers = self.users.filter { user in
            guard let userID = user.id else { return false }
            let isInteracted = self.interactedUsers.contains(userID)
            if isInteracted {
                print("DEBUG: Skipping user \(userID) (already interacted).")
            }
            return !isInteracted
        }

        self.users = nonInteractedUsers
        print("DEBUG: Total users after filtering: \(self.users.count)")
    }

    

    // MARK: - Existing listeners & helper functions
    private func listenForMatchNotifications() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("MatchCreated"),
            object: nil,
            queue: .main
        ) { notification in
            if let message = notification.object as? String {
                self.alertMessage = message
                self.showAlert = true
            }
        }
    }

    private func listenForUserDeletions() {
        let db = Firestore.firestore()
        db.collection("users").addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error listening for deletions: \(error.localizedDescription)")
                return
            }
            snapshot?.documentChanges.forEach { change in
                if change.type == .removed {
                    if let deletedUser = try? change.document.data(as: UserProfile.self),
                       let userID = deletedUser.id {
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
        UserDefaults.standard.removeObject(forKey: "interactedUsers_\(currentUserID)")
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
                    do {
                        let user = try change.document.data(as: UserProfile.self)
                        guard let userID = user.id else { return }

                        // Add the condition here
                        if userID != currentUserID, !self.interactedUsers.contains(userID) {
                            self.users.append(user)
                            self.shownUserIDs.insert(userID)
                            print("DEBUG: New user added: \(userID)")
                        } else {
                            print("DEBUG: Skipping user \(userID) - Current user or already interacted.")
                        }
                    } catch {
                        print("DEBUG: Error parsing new user document \(change.document.documentID): \(error.localizedDescription)")
                    }
                }
            }
            print("DEBUG: Users after listening for new additions: \(self.users.count)")
        }
    }


    func fetchAllUsers(includeCurrentUser: Bool = false, completion: @escaping () -> Void) {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            completion()
            return
        }
        let db = Firestore.firestore()
        db.collection("users").getDocuments { snapshot, error in
            if let error = error {
                print("DEBUG: Firestore query failed: \(error.localizedDescription)")
                completion()
                return
            }

            guard let docs = snapshot?.documents else {
                print("DEBUG: No user documents found.")
                completion()
                return
            }

            var fetched: [UserProfile] = []

            for doc in docs {
                do {
                    var user = try doc.data(as: UserProfile.self)
                    guard let userID = user.id else { continue }

                    // Optionally skip current user
                    if userID == currentUserID && !includeCurrentUser {
                        continue
                    }

                    // If the user was recently updated and meets feed criteria, re-add them
                    if !self.interactedUsers.contains(userID) {
                        fetched.append(user)
                    }

                } catch {
                    print("DEBUG: parse error: \(error.localizedDescription)")
                }
            }

            // Now merge them instead of overwriting
            for newUser in fetched {
                if let index = self.users.firstIndex(where: { $0.id == newUser.id }) {
                    self.users[index] = newUser
                } else {
                    self.users.append(newUser)
                }
            }

            completion()
        }
    }



    func handleProfileUpdate() {
        fetchAllUsers(includeCurrentUser: true) {
            print("DEBUG: Refreshed user list, including current user after profile update.")
            // Optionally trigger a UI update or reload ContentView here
        }
    }


    func deleteAccount() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("DEBUG: Current user is not authenticated.")
            return
        }

        let db = Firestore.firestore()

        // Fetch the username before deleting the user
        db.collection("users").document(currentUserID).getDocument { document, error in
            if let error = error {
                print("DEBUG: Error fetching user document for deletion: \(error.localizedDescription)")
                return
            }

            guard let data = document?.data(), let username = data["username"] as? String else {
                print("DEBUG: Username not found for current user.")
                return
            }

            // Delete the user document
            db.collection("users").document(currentUserID).delete { error in
                if let error = error {
                    print("DEBUG: Error deleting user document: \(error.localizedDescription)")
                    return
                }

                print("DEBUG: User document deleted successfully.")

                // Delete the username from the centralized usernames collection
                db.collection("usernames").document(username).delete { error in
                    if let error = error {
                        print("DEBUG: Error deleting username: \(error.localizedDescription)")
                    } else {
                        print("DEBUG: Username \(username) deleted successfully.")
                    }
                }

                // Delete the account from Firebase Authentication
                Auth.auth().currentUser?.delete { error in
                    if let error = error {
                        print("DEBUG: Error deleting Firebase Authentication account: \(error.localizedDescription)")
                    } else {
                        print("DEBUG: Firebase Authentication account deleted successfully.")
                    }
                }
            }
        }
    }

    func validateAndSaveUsername(username: String, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()

        // Check if username exists
        db.collection("usernames").document(username).getDocument { document, error in
            if let error = error {
                print("DEBUG: Error checking username: \(error.localizedDescription)")
                completion(false)
                return
            }

            if document?.exists == true {
                print("DEBUG: Username \(username) is already taken.")
                completion(false)
            } else {
                // Save username in the usernames collection
                db.collection("usernames").document(username).setData(["createdAt": Timestamp()]) { error in
                    if let error = error {
                        print("DEBUG: Error saving username: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        print("DEBUG: Username \(username) saved successfully.")
                        completion(true)
                    }
                }
            }
        }
    }

    
    
    private func processFetchedUsers(documents: [QueryDocumentSnapshot], currentUserID: String) {
        var fetchedUsers: [UserProfile] = []
        var skippedUsers: [String] = []

        for document in documents {
            do {
                let user = try document.data(as: UserProfile.self)
                guard let userID = user.id else {
                    print("DEBUG: Skipping user - Missing user ID for document \(document.documentID)")
                    skippedUsers.append(document.documentID)
                    continue
                }

                // Add the condition here
                if userID != currentUserID, !self.interactedUsers.contains(userID) {
                    fetchedUsers.append(user)
                    print("DEBUG: User fetched: \(userID), Name: \(user.name ?? "Unknown")")
                } else {
                    print("DEBUG: Skipping user \(userID) - Current user or already interacted.")
                    skippedUsers.append(userID)
                }
            } catch {
                print("DEBUG: Error decoding user \(document.documentID): \(error.localizedDescription)")
                skippedUsers.append(document.documentID)
            }
        }

        self.users = fetchedUsers
        print("DEBUG: Total users added: \(fetchedUsers.count)")
        print("DEBUG: Skipped users: \(skippedUsers)")
    }



    // MARK: - Unread message logic
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
        self.unreadMessagesListener?.remove()

        var listeners: [ListenerRegistration] = []

        // For matches where currentUserID is user1
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
                        self.processSnapshot(snapshot: snapshot, currentUserID: currentUserID, isUser1: true)
                        if UIApplication.shared.applicationState != .active {
                            self.sendPushNotification(for: matchID)
                        }
                    }
                }
            }
        listeners.append(listener1)

        // For matches where currentUserID is user2
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
                        if UIApplication.shared.applicationState != .active {
                            self.sendPushNotification(for: matchID)
                        }
                    }
                }
            }
        listeners.append(listener2)

        self.unreadMessagesListener = ListenerRegistrationGroup(listeners: listeners)
    }

    private func sendPushNotification(for matchID: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
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

                let title = "New Message from \(senderName)"
                let body = messageText

                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default

                let request = UNNotificationRequest(identifier: UUID().uuidString,
                                                    content: content,
                                                    trigger: nil)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.isInChatView {
                    print("DEBUG: Preventing unreadMessagesCount update while in ChatView.")
                    return
                }
                self.unreadMessagesCount = totalUnreadMessages
                print("DEBUG: Updating unreadMessagesCount to \(totalUnreadMessages)")
            }
        }
    }

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
            print("DEBUG: Skipping fetchUnreadMessagesCountForMatch for matchID \(matchID)")
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
            return
        }
        guard let senderName = latestMessage.data()["senderName"] as? String,
              let messageText = latestMessage.data()["text"] as? String else { return }

        let alertMessage = "\(senderName): \(messageText)"
        self.bannerMessage = alertMessage
        self.showNotificationBanner = true
    }

    private func notifyUserOfNewMessages(senderName: String, messageText: String) {
        guard UIApplication.shared.applicationState != .active else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "New Message from \(senderName)"
        content.body = messageText
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Like/Pass & Match Logic
    private func likeAction() {
        interactionResult = .liked
        guard currentIndex < users.count else { return }

        let likedUser = users[currentIndex]
        guard let likedUserID = likedUser.id else {
            print("Error: Liked user does not have an ID.")
            return
        }

        print("DEBUG: Liking user \(likedUserID).")
        moveToNextUser()

        // Add to Firestore and handle potential match creation
        let db = Firestore.firestore()
        let currentUserID = Auth.auth().currentUser?.uid ?? ""

        let likeData: [String: Any] = [
            "likingUserID": currentUserID,
            "likedUserID": likedUserID,
            "timestamp": Timestamp()
        ]

        db.collection("likes").addDocument(data: likeData) { error in
            if let error = error {
                print("ERROR: Failed to save like for user \(likedUserID): \(error.localizedDescription)")
                return
            }

            print("DEBUG: Like saved for user \(likedUserID).")

            // Check if the liked user also liked the current user
            db.collection("likes")
                .whereField("likedUserID", isEqualTo: currentUserID)
                .whereField("likingUserID", isEqualTo: likedUserID)
                .getDocuments { querySnapshot, error in
                    if let error = error {
                        print("ERROR: Failed to check for match: \(error.localizedDescription)")
                        return
                    }

                    if querySnapshot?.isEmpty == false {
                        print("DEBUG: Match found with user \(likedUserID).")
                        self.createMatch(
                            currentUserID: currentUserID,
                            likedUserID: likedUserID,
                            likedUser: likedUser
                        )
                    }
                }
        }

        markUserAsInteracted(userID: likedUserID, interactionType: "liked")
    }

    private func passAction() {
        interactionResult = .passed
        guard currentIndex < users.count else { return }

        let skippedUser = users[currentIndex]
        guard let skippedUserID = skippedUser.id else {
            print("DEBUG: Skipped user does not have an ID.")
            return
        }

        print("DEBUG: Passing user \(skippedUserID).")
        moveToNextUser()

        markUserAsInteracted(userID: skippedUserID, interactionType: "swiped left")
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
        db.collection("matches")
          .whereField("user1", isEqualTo: currentUserID)
          .addSnapshotListener { snapshot, error in
              if let error = error {
                  print("Error listening for matches (user1): \(error.localizedDescription)")
                  return
              }
              self.handleMatchChanges(snapshot: snapshot, currentUserID: currentUserID)
          }
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
                    continue
                }
                processedMatchIDs.insert(matchID)

                let matchData = change.document.data()
                let user1 = matchData["user1"] as? String ?? ""
                let user2 = matchData["user2"] as? String ?? ""
                let otherUserID = (user1 == currentUserID) ? user2 : user1

                if let notificationsSent = matchData["notificationsSent"] as? [String: Bool],
                   notificationsSent[currentUserID] == true {
                    continue
                }

                var updatedNotificationsSent = matchData["notificationsSent"] as? [String: Bool] ?? [:]
                updatedNotificationsSent[currentUserID] = true

                let db = Firestore.firestore()
                db.collection("matches").document(matchID).updateData(["notificationsSent": updatedNotificationsSent]) { error in
                    if let error = error {
                        print("ERROR: Failed to update notificationsSent for match \(matchID): \(error.localizedDescription)")
                    }
                }

                fetchUserName(userID: otherUserID) { userName in
                    let message = "You matched with \(userName)!"
                    self.showInAppMatchNotification(message: message)
                }
            }
        }
    }

    private func showInAppMatchNotification(message: String) {
        self.inAppNotificationMessage = message
        self.showInAppMatchNotification = true
    }

    private func recordMatchNotification(message: String) {
        DispatchQueue.main.async {
            self.notifications.append(message)
            self.notificationCount += 1
            print("DEBUG: Match notification recorded: \(message)")
        }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showNotificationBanner = false
        }
    }

    private func fetchUserNameAndNotify(matchData: [String: Any], currentUserID: String) {
        let user1 = matchData["user1"] as? String ?? ""
        let user2 = matchData["user2"] as? String ?? ""
        let otherUserID = (user1 == currentUserID) ? user2 : user1
        fetchUserName(userID: otherUserID) { userName in
            let message = "You matched with \(userName)!"
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
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
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
        let serverKey = "AIzaSyA-Eew48TEhrZnX80C8lyYcKkuYRx0hNME"

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
                    if let data = data,
                       let responseString = String(data: data, encoding: .utf8) {
                        print("Response data: \(responseString)")
                    }
                } else {
                    print("Push notification sent successfully to token: \(fcmToken)")
                }
            }
        }
        task.resume()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("DEBUG: Notification tapped. UserInfo: \(userInfo)")
        if let match = userInfo["match"] as? String, match == "yes" {
            print("DEBUG: Match notification tapped.")
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("DEBUG: Received notification in foreground: \(notification.request.content.userInfo)")
        if let match = notification.request.content.userInfo["match"] as? String, match == "yes" {
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

    

    private func moveToNextUser() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.interactionResult = nil
                self.currentIndex += 1

                if self.currentIndex >= self.users.count {
                    self.currentIndex = 0
                    self.users.removeAll()
                }

                print("DEBUG: Current index moved to \(self.currentIndex). Total users remaining: \(self.users.count).")
                UserDefaults.standard.set(self.currentIndex, forKey: "currentIndex")
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

// MARK: - BadgeView & NotificationsView
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
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.gray]),
                startPoint: .top,
                endPoint: .bottom
            )
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
import Kingfisher
import AVKit

// MARK: - UserCardView
struct UserCardView: View {
    var user: UserProfile
    var newMedia: [MediaItem] = []
    
    @State private var currentMediaIndex = 0
    
    // Dictionary of preloaded AVPlayers: [videoURL: AVPlayer]
    @State private var videoPlayers: [URL: AVPlayer] = [:]
    
    // Combine the user's media with any newMedia, filtering for valid URLs
    private var allMediaItems: [MediaItem] {
        let mediaItems = (user.mediaItems ?? []) + newMedia
        return mediaItems.filter { $0.url.isPublicURL }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // A paged TabView for swiping media
                TabView(selection: $currentMediaIndex) {
                    ForEach(allMediaItems.indices, id: \.self) { index in
                        let mediaItem = allMediaItems[index]
                        ZStack {
                            if mediaItem.type == .video {
                                if let existingPlayer = videoPlayers[mediaItem.url] {
                                    // Use a specialized view that DOES NOT auto-play on appear
                                    PreloadedVideoPlayerView(
                                        player: existingPlayer,
                                        url: mediaItem.url
                                    )
                                    .cornerRadius(20)
                                    .padding(.horizontal, 10)
                                    .tag(index)
                                } else {
                                    // Show a simple loading placeholder if the AVPlayer is still loading
                                    Text("Loading video...")
                                        .foregroundColor(.white)
                                        .frame(
                                            width: UIScreen.main.bounds.width * 0.9,
                                            height: UIScreen.main.bounds.height * 0.5
                                        )
                                        .background(Color.black)
                                        .cornerRadius(20)
                                        .tag(index)
                                }
                            } else {
                                // Image media
                                KFImage(mediaItem.url)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(
                                        width: UIScreen.main.bounds.width * 0.9,
                                        height: UIScreen.main.bounds.height * 0.5
                                    )
                                    .clipped()
                                    .cornerRadius(20)
                                    .tag(index)
                            }
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                // Disable default TabView animations for smoother swiping
                .animation(.none, value: currentMediaIndex)
                .frame(height: UIScreen.main.bounds.height * 0.5)
                
                // --- NEW: Only the current index video gets played; others are paused ---
                .onChange(of: currentMediaIndex) { newIndex in
                    // Pause all videos
                    for (_, player) in videoPlayers {
                        player.pause()
                        player.seek(to: .zero) // Optionally reset them
                    }
                    // If the newly selected media is a video, play it
                    let mediaItem = allMediaItems[newIndex]
                    if mediaItem.type == .video,
                       let thisPlayer = videoPlayers[mediaItem.url] {
                        thisPlayer.play()
                    }
                }
            }
            
            // Example user info area below
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
        .onAppear {
            preloadAllVideos()
        }
    }
    
    // MARK: - Video Preloading
        
        /// Preload each video in 'allMediaItems' by asynchronously creating an AVPlayer
        private func preloadAllVideos() {
            for media in allMediaItems where media.type == .video {
                // If we don’t already have a player cached:
                if videoPlayers[media.url] == nil {
                    Task {
                        if let player = await createPreloadedPlayer(for: media.url) {
                            // Store it so that we never have to re-create it again
                            DispatchQueue.main.async {
                                videoPlayers[media.url] = player
                            }
                        }
                    }
                }
            }
        }
        
    /// Asynchronously load the required asset keys, create an AVPlayer
        private func createPreloadedPlayer(for url: URL) async -> AVPlayer? {
            let asset = AVAsset(url: url)
            let requiredKeys = ["playable", "hasProtectedContent"]
            
            do {
                // Load the keys asynchronously
                try await asset.loadValues(forKeys: requiredKeys)
                let item = AVPlayerItem(asset: asset)
                let player = AVPlayer(playerItem: item)
                // NOTE: We do NOT call player.play() here. We'll only play once at the correct index
                return player
            } catch {
                print("ERROR: Could not preload video for URL \(url): \(error.localizedDescription)")
                return nil
            }
        }
    }

    // MARK: - PreloadedVideoPage
    /// A single “page” in the TabView that uses a preloaded AVPlayer and auto-plays the video.
    struct PreloadedVideoPage: View {
        @StateObject private var viewModel = VideoPageViewModel()
        
        let player: AVPlayer
        let url: URL
        
        var body: some View {
            GeometryReader { geo in
                VideoPlayer(player: player)
                    .scaleEffect(viewModel.calculateScale(geometry: geo, isHorizontal: viewModel.isHorizontalVideo))
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .cornerRadius(20)
                    .padding(.horizontal, 10)
                    .onAppear {
                        // Once we appear, check orientation, play video
                        viewModel.checkVideoOrientation(url)
                        player.seek(to: .zero)
                        player.play()
                        viewModel.addReplayObserver(player: player)
                    }
                    .onDisappear {
                        // Avoid playing multiple videos off-screen
                        player.pause()
                        // Optionally reset to the start
                        player.seek(to: .zero)
                    }
                    .onTapGesture {
                        // If horizontal => open fullscreen
                        if viewModel.isHorizontalVideo {
                            viewModel.showFullScreenPlayer = true
                        } else {
                            // If vertical => toggle play/pause
                            if player.timeControlStatus == .playing {
                                player.pause()
                            } else {
                                player.play()
                            }
                        }
                    }
                    .fullScreenCover(isPresented: $viewModel.showFullScreenPlayer) {
                        FullScreenVideoPlayer(url: url, isHorizontalVideo: viewModel.isHorizontalVideo)
                    }
            }
        }
    }


/// A view model for each video “page” to handle orientation logic and replay observer.
final class VideoPageViewModel: ObservableObject {
    @Published var isHorizontalVideo: Bool = false
    @Published var showFullScreenPlayer: Bool = false
    
    func checkVideoOrientation(_ url: URL) {
        let asset = AVAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else { return }
        let dims = track.naturalSize.applying(track.preferredTransform)
        isHorizontalVideo = abs(dims.width) > abs(dims.height)
    }
    
    func addReplayObserver(player: AVPlayer) {
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
    }
    
    /// For a slight “zoom in” effect, similar to Instagram
    func calculateScale(geometry: GeometryProxy, isHorizontal: Bool) -> CGFloat {
        let videoAspectRatio = isHorizontal ? 16.0 / 9.0 : 9.0 / 16.0
        let viewAspectRatio = geometry.size.width / geometry.size.height
        let baseScale = max(viewAspectRatio / videoAspectRatio, 1.0)
        return baseScale * 1.15
    }
}


// Just keep your `URL.isPublicURL` check:
extension URL {
    var isPublicURL: Bool {
        absoluteString.hasPrefix("https://")
    }
}




import SwiftUI
import AVKit

import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let url: URL
    @State private var player: AVPlayer
    @State private var isHorizontalVideo = false
    @State private var showFullScreenPlayer = false

    init(url: URL) {
        self.url = url
        self._player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                VideoPlayer(player: player)
                    .scaleEffect(calculateScale(geometry: geometry)) // Apply zoom for both orientations
                    .frame(width: geometry.size.width, height: geometry.size.height) // Match container size
                    .clipped() // Ensure no overflow
                    .onAppear {
                        checkVideoOrientation()
                        player.seek(to: .zero)
                        player.play()
                        addReplayObserver()
                    }
                    .onDisappear {
                        player.pause()
                    }
                    .onTapGesture {
                        if isHorizontalVideo {
                            showFullScreenPlayer = true // Open fullscreen for horizontal videos
                        } else {
                            // Toggle play/pause for vertical videos
                            if player.timeControlStatus == .playing {
                                player.pause()
                            } else {
                                player.play()
                            }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showFullScreenPlayer) {
            FullScreenVideoPlayer(url: url, isHorizontalVideo: isHorizontalVideo)
        }
    }

    // Function to calculate scale for both horizontal and vertical videos
    private func calculateScale(geometry: GeometryProxy) -> CGFloat {
        let videoAspectRatio = isHorizontalVideo ? 16.0 / 9.0 : 9.0 / 16.0
        let viewAspectRatio = geometry.size.width / geometry.size.height
        let baseScale = max(viewAspectRatio / videoAspectRatio, 1.0)
        return baseScale * 1.15 // Adjust for slightly zoomed effect
    }

    private func checkVideoOrientation() {
        let asset = AVAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else { return }
        let dimensions = track.naturalSize.applying(track.preferredTransform)
        isHorizontalVideo = abs(dimensions.width) > abs(dimensions.height)
    }

    private func addReplayObserver() {
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
    }
    
    private func configureAudioSession() {
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(.playback, mode: .moviePlayback, options: .mixWithOthers)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                print("Failed to configure audio session: \(error.localizedDescription)")
            }
        }
    
    private func preloadVideo(url: URL, completion: @escaping (AVPlayer?) -> Void) {
        let asset = AVAsset(url: url)
        let keys = ["playable", "hasProtectedContent"]
        asset.loadValuesAsynchronously(forKeys: keys) {
            DispatchQueue.main.async {
                for key in keys {
                    var error: NSError?
                    let status = asset.statusOfValue(forKey: key, error: &error)
                    if status == .failed || status == .cancelled {
                        print("DEBUG: Failed to load key \(key): \(error?.localizedDescription ?? "Unknown error")")
                        completion(nil)
                        return
                    }
                }
                completion(AVPlayer(playerItem: AVPlayerItem(asset: asset)))
            }
        }
    }
    


}
