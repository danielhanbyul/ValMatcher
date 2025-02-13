//
//  ValMatcherApp.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/6/24.
//

import SwiftUI
import Firebase
import UserNotifications
import FirebaseMessaging
import UIKit

@main
struct ValMatcherApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
                .onAppear {
                    appState.listenForMatches()
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    var window: UIWindow?
    var orientationLock = UIInterfaceOrientationMask.portrait  // Default orientation is portrait
    var cachedFCMToken: String?  // Cache FCM token until user is authenticated

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("DEBUG: Application didFinishLaunchingWithOptions started.")

        // Configure Firebase
        FirebaseApp.configure()
        print("DEBUG: Firebase configured successfully.")

        // Set the delegate for UNUserNotificationCenter
        UNUserNotificationCenter.current().delegate = self
        print("DEBUG: UNUserNotificationCenter delegate set.")

        // Check and request notification permissions
        checkNotificationPermissions()

        // Register for remote notifications
        application.registerForRemoteNotifications()
        print("DEBUG: Registering for remote notifications.")

        // Set the delegate for Firebase Messaging
        Messaging.messaging().delegate = self
        print("DEBUG: Firebase Messaging delegate set.")

        // Add notificationsSent field to existing matches (if you need to run once)
        addNotificationsSentToMatches()

        // Observe authentication state changes
        Auth.auth().addStateDidChangeListener { auth, user in
            if let user = user {
                print("DEBUG: User authenticated with UID: \(user.uid)")
                // If we had a cached FCM token from before auth, update now
                if let cachedToken = self.cachedFCMToken {
                    print("DEBUG: Updating FCM token from cache: \(cachedToken)")
                    self.updateFCMTokenInFirestore(fcmToken: cachedToken)
                } else {
                    // Otherwise fetch a fresh token
                    Messaging.messaging().token { token, error in
                        if let error = error {
                            print("ERROR: Failed to fetch FCM registration token: \(error.localizedDescription)")
                        } else if let token = token {
                            print("DEBUG: FCM registration token fetched after user auth: \(token)")
                            self.updateFCMTokenInFirestore(fcmToken: token)
                        } else {
                            print("ERROR: FCM token fetch returned nil.")
                        }
                    }
                }
            } else {
                print("DEBUG: No user is authenticated.")
            }
        }

        return true
    }

    // MARK: - Notification Permissions
    private func checkNotificationPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                // Request permissions
                self.requestNotificationPermission()
            case .denied:
                print("DEBUG: Notifications are denied.")
            case .authorized, .provisional:
                print("DEBUG: Notifications are authorized.")
            @unknown default:
                print("DEBUG: Unknown notification permissions state.")
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("ERROR: Failed to request notification permissions: \(error.localizedDescription)")
            } else if granted {
                print("DEBUG: Notifications permission granted.")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("DEBUG: Notifications permission denied by the user.")
            }
        }
    }


    // MARK: - APNs Registration
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("DEBUG: Successfully registered for remote notifications.")
        Messaging.messaging().apnsToken = deviceToken
        print("DEBUG: APNs token passed to Firebase.")
    }


    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("ERROR: Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // MARK: - Foreground Notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("DEBUG: Received notification in foreground: \(notification.request.content.userInfo)")
        // Show the default iOS banner and sound, even in the foreground
        completionHandler([.banner, .sound, .badge])
    }

    // MARK: - Notification Tap
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("DEBUG: Notification tapped. UserInfo: \(userInfo)")

        if let messageId = userInfo["messageId"] as? String {
            print("DEBUG: Extracted messageId: \(messageId)")
            navigateToChat(withMessageId: messageId)
        }
        completionHandler()
    }

    // MARK: - FCM Token Handling
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else {
            print("ERROR: FCM token is nil.")
            return
        }
        print("DEBUG: FCM token received: \(fcmToken)")
        self.cachedFCMToken = fcmToken
        updateFCMTokenInFirestore(fcmToken: fcmToken)
    }

    private func updateFCMTokenInFirestore(fcmToken: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("DEBUG: No authenticated user to update FCM token. Caching token.")
            self.cachedFCMToken = fcmToken
            return
        }

        let db = Firestore.firestore()
        print("DEBUG: Updating FCM token in Firestore for user: \(currentUserID). Token: \(fcmToken)")
        db.collection("users").document(currentUserID).setData(["fcmToken": fcmToken], merge: true) { error in
            if let error = error {
                print("ERROR: Error updating FCM token in Firestore: \(error.localizedDescription)")
            } else {
                print("DEBUG: Successfully updated FCM token in Firestore for user \(currentUserID).")
                self.cachedFCMToken = nil  // Clear cached token after successful update
            }
        }
    }

    // MARK: - Custom Navigation
    private func navigateToChat(withMessageId messageId: String) {
        print("DEBUG: Navigating to chat with message ID: \(messageId)")
        // Implement your custom navigation logic here.
    }

    // MARK: - Silent Notification for Background Fetch
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("DEBUG: Remote notification received with userInfo: \(userInfo)")

        if let contentAvailable = userInfo["content-available"] as? Int, contentAvailable == 1 {
            print("DEBUG: Silent notification detected. Fetching new data.")
            fetchNewData { result in
                completionHandler(result)
            }
        } else {
            print("DEBUG: Regular notification received.")
            completionHandler(.noData)
        }
    }

    private func fetchNewData(completion: @escaping (UIBackgroundFetchResult) -> Void) {
        print("DEBUG: Fetching new data for silent notification.")
        // Add data-fetching logic here.
        completion(.newData)
    }

    // MARK: - Orientation Lock
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .pad {
            // Default to portrait for iPad, but allow all orientations for full-screen video
            return self.orientationLock == .all ? .all : .portrait
        } else {
            return self.orientationLock // iPhone remains unchanged
        }
    }

    
}

// MARK: - Extend AppDelegate for "addNotificationsSentToMatches" if needed
extension AppDelegate {
    /// (Optional) Example function to add a `notificationsSent` field to all existing matches
    /// so we don't re-trigger for older matches. This might only need to run once in your lifetime,
    /// or you can remove it if you already have `notificationsSent` in every match doc.
    func addNotificationsSentToMatches() {
        let db = Firestore.firestore()
        db.collection("matches").getDocuments { snapshot, error in
            if let error = error {
                print("DEBUG: Error fetching matches for addNotificationsSentToMatches: \(error.localizedDescription)")
                return
            }
            snapshot?.documents.forEach { document in
                var data = document.data()
                if data["notificationsSent"] == nil {
                    data["notificationsSent"] = [String: Bool]()
                    db.collection("matches").document(document.documentID).setData(data, merge: true) { err in
                        if let err = err {
                            print("DEBUG: Error setting notificationsSent for \(document.documentID): \(err.localizedDescription)")
                        } else {
                            print("DEBUG: notificationsSent initialized for matchID: \(document.documentID)")
                        }
                    }
                }
            }
        }
    }
}




import SwiftUI
import Firebase

class AppState: ObservableObject {
    @Published var isInChatView: Bool = false
    @Published var currentChatID: String?
    @Published var alertMessage: String = ""
    @Published var showAlert: Bool = false

    private var chatListeners: [String: ListenerRegistration] = [:]
    private var hasStartedListeningForMatches = false
    private var processedMatchIDs: Set<String> = []  // To avoid duplicate notifications

    // Public accessor for processedMatchIDs
    func isMatchProcessed(_ matchID: String) -> Bool {
        return processedMatchIDs.contains(matchID)
    }

    func markMatchAsProcessed(_ matchID: String) {
        processedMatchIDs.insert(matchID)
    }

    // Add a chat listener for a specific chat ID
    func addChatListener(for chatID: String, listener: ListenerRegistration) {
        print("DEBUG: Adding chat listener for chatID: \(chatID)")
        chatListeners[chatID] = listener
    }

    // Remove a specific chat listener by chat ID
    func removeChatListener(for chatID: String) {
        if let listener = chatListeners[chatID] {
            listener.remove()
            chatListeners.removeValue(forKey: chatID)
            print("DEBUG: Listener removed for chatID: \(chatID)")
        } else {
            print("DEBUG: No listener found for chatID: \(chatID)")
        }
    }

    // Remove all chat listeners
    func removeAllChatListeners() {
        print("DEBUG: Removing all chat listeners.")
        for (chatID, listener) in chatListeners {
            listener.remove()
            print("DEBUG: Removed listener for chatID: \(chatID)")
        }
        chatListeners.removeAll()
    }

    // Listen for new matches involving the current user
    func listenForMatches() {
        guard !hasStartedListeningForMatches else { return }  // Prevent multiple listeners
        hasStartedListeningForMatches = true

        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("DEBUG: User not authenticated.")
            return
        }

        let db = Firestore.firestore()

        // Listen for matches where the current user is `user1`
        db.collection("matches")
            .whereField("user1", isEqualTo: currentUserID)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("DEBUG: Error listening for matches (user1): \(error.localizedDescription)")
                    return
                }
                self.processMatchChanges(snapshot: snapshot, currentUserID: currentUserID)
            }

        // Listen for matches where the current user is `user2`
        db.collection("matches")
            .whereField("user2", isEqualTo: currentUserID)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("DEBUG: Error listening for matches (user2): \(error.localizedDescription)")
                    return
                }
                self.processMatchChanges(snapshot: snapshot, currentUserID: currentUserID)
            }
    }

    private func processMatchChanges(snapshot: QuerySnapshot?, currentUserID: String) {
        guard let snapshot = snapshot else { return }

        for change in snapshot.documentChanges {
            if change.type == .added {
                let matchID = change.document.documentID
                let matchData = change.document.data()

                // Skip if already processed
                if processedMatchIDs.contains(matchID) {
                    print("DEBUG: Skipping already processed match \(matchID)")
                    continue
                }

                // Skip if notificationsSent is already true for the current user
                if let notificationsSent = matchData["notificationsSent"] as? [String: Bool],
                   notificationsSent[currentUserID] == true {
                    print("DEBUG: Notifications already sent for match \(matchID)")
                    continue
                }

                // Mark this match as processed
                processedMatchIDs.insert(matchID)

                // Extract user1 and user2 from matchData
                let user1 = matchData["user1"] as? String ?? ""
                let user2 = matchData["user2"] as? String ?? ""

                // Determine the other user's ID
                let otherUserID = (user1 == currentUserID) ? user2 : user1

                // 1) Fetch the other user's name
                fetchUserName(userID: otherUserID) { otherUserName in
                    let message = "You matched with \(otherUserName)!"

                    // 2) Send a push notification to *both* the current user AND the other user
                    //    so both get the same default iOS banner if backgrounded.
                    self.sendMatchPushNotification(toUserID: currentUserID, body: message)
                    self.sendMatchPushNotification(toUserID: otherUserID, body: message)

                    // 3) Mark notificationsSent in Firestore for the current user
                    var updatedNotificationsSent = matchData["notificationsSent"] as? [String: Bool] ?? [:]
                    updatedNotificationsSent[currentUserID] = true

                    Firestore.firestore().collection("matches").document(matchID).updateData([
                        "notificationsSent": updatedNotificationsSent
                    ]) { error in
                        if let error = error {
                            print("DEBUG: Error updating notificationsSent for match \(matchID): \(error.localizedDescription)")
                        } else {
                            print("DEBUG: Updated notificationsSent for match \(matchID)")
                        }
                    }
                }
            }
        }
    }

    // Fetch the user's name from Firestore by user ID
    private func fetchUserName(userID: String, completion: @escaping (String) -> Void) {
        let db = Firestore.firestore()
        db.collection("users").document(userID).getDocument { document, error in
            if let error = error {
                print("DEBUG: Error fetching user name: \(error.localizedDescription)")
                completion("Unknown")
                return
            }
            let userName = document?.data()?["name"] as? String ?? "Unknown"
            completion(userName)
        }
    }

    // MARK: - NEW: Send push notification to userID
    private func sendMatchPushNotification(toUserID: String, body: String) {
        let db = Firestore.firestore()
        db.collection("users").document(toUserID).getDocument { document, error in
            if let error = error {
                print("DEBUG: Error fetching user doc: \(error.localizedDescription)")
                return
            }
            guard let doc = document, doc.exists,
                  let data = doc.data(),
                  let fcmToken = data["fcmToken"] as? String, !fcmToken.isEmpty
            else {
                print("DEBUG: No fcmToken found for userID \(toUserID)")
                return
            }
            // Actually send via FCM
            self.sendPushNotification(to: fcmToken, title: "Match Found!", body: body)
        }
    }

    // MARK: - FCM HTTPS call
    private func sendPushNotification(to fcmToken: String, title: String, body: String) {
        let urlString = "https://fcm.googleapis.com/fcm/send"
        guard let url = URL(string: urlString) else { return }

        // TODO: Replace with your actual Server Key from the Firebase Console
        let serverKey = "YOUR_SERVER_KEY_HERE"

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
                print("DEBUG: Error sending push notification: \(error.localizedDescription)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("DEBUG: Push notification sent successfully to token: \(fcmToken)")
                } else {
                    print("DEBUG: Push notification failed with status: \(httpResponse.statusCode)")
                    if let data = data,
                       let responseString = String(data: data, encoding: .utf8) {
                        print("DEBUG: Response: \(responseString)")
                    }
                }
            }
        }
        task.resume()
    }

    // MARK: - (Optional) If you still want a SwiftUI in-app alert for *other* use cases
    func showMatchNotification(message: String) {
        // You can still keep a SwiftUI alert for debugging or other reasons
        DispatchQueue.main.async {
            self.alertMessage = message
            self.showAlert = true
            print("DEBUG: (Optional) SwiftUI alert: \(message)")
        }
    }
}
