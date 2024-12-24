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

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
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

        // Add notificationsSent field to existing matches
        addNotificationsSentToMatches()  // Call this function during app launch (temporary)

        // Observe authentication state changes
        Auth.auth().addStateDidChangeListener { auth, user in
            if let user = user {
                print("DEBUG: User authenticated with UID: \(user.uid)")
                if let cachedToken = self.cachedFCMToken {
                    print("DEBUG: Updating FCM token from cache: \(cachedToken)")
                    self.updateFCMTokenInFirestore(fcmToken: cachedToken)
                } else {
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

    // Check notification permissions and request them if not determined
    private func checkNotificationPermissions() {
        print("DEBUG: Checking notification permissions.")
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                print("DEBUG: Notifications not determined. Requesting permissions.")
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

    // Request notification permissions
    private func requestNotificationPermission() {
        print("DEBUG: Requesting notification permissions.")
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

    // Handle successful registration for remote notifications
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("DEBUG: Successfully registered for remote notifications.")
        Messaging.messaging().apnsToken = deviceToken
        print("DEBUG: APNs token passed to Firebase.")
    }

    // Handle failure to register for remote notifications
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("ERROR: Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // Handle foreground notifications
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("DEBUG: Received notification in foreground: \(notification.request.content.userInfo)")
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification tap actions
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("DEBUG: Notification tapped. UserInfo: \(userInfo)")

        if let messageId = userInfo["messageId"] as? String {
            print("DEBUG: Extracted messageId: \(messageId)")
            navigateToChat(withMessageId: messageId)
        }
        completionHandler()
    }

    // Handle token refresh for FCM
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else {
            print("ERROR: FCM token is nil.")
            return
        }
        print("DEBUG: FCM token received: \(fcmToken)")
        self.cachedFCMToken = fcmToken
        updateFCMTokenInFirestore(fcmToken: fcmToken)
    }

    // Update FCM token in Firestore
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

    // Custom function to navigate to a specific chat/message when a notification is tapped
    private func navigateToChat(withMessageId messageId: String) {
        print("DEBUG: Navigating to chat with message ID: \(messageId)")
        // Implement navigation logic here.
    }

    // Handle silent notifications for background fetches or data updates
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
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

    // Orientation locking logic
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return self.orientationLock
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
                let otherUserID = user1 == currentUserID ? user2 : user1

                // Fetch the other user's name and display a notification
                fetchUserName(userID: otherUserID) { userName in
                    let message = "You matched with \(userName)!"
                    self.showMatchNotification(message: message)

                    // Update Firestore to mark notification as sent
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

    // Show a match notification with the given message
    func showMatchNotification(message: String) {
        print("DEBUG: Preparing to show notification: \(message)")
        DispatchQueue.main.async {
            self.alertMessage = message
            self.showAlert = true
            print("DEBUG: Match notification shown: \(message)")
        }
    }
}
