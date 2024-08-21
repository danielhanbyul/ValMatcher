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

@main
struct ValMatcherApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            MainView()  // Ensure MainView is used here for handling navigation
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()

        // Set the delegate for UNUserNotificationCenter
        UNUserNotificationCenter.current().delegate = self

        // Request notification authorization
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Error requesting notification permissions: \(error.localizedDescription)")
            } else {
                print("Notification permission granted: \(granted)")
            }
        }

        // Register for remote notifications
        application.registerForRemoteNotifications()

        // Set the delegate for FCM
        Messaging.messaging().delegate = self

        return true
    }

    // Handle successful registration for remote notifications
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Set the APNs token for Firebase Cloud Messaging
        Messaging.messaging().apnsToken = deviceToken
        print("Successfully registered for remote notifications.")
    }

    // Handle failure to register for remote notifications
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // Handle notifications when the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show the notification as an alert, with sound and badge
        completionHandler([.banner, .badge, .sound])
    }

    // Handle notification tap action
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle the notification data and navigate to the appropriate view
        if let messageId = userInfo["messageId"] as? String {
            // Assuming you have a way to navigate to specific chat/message
            navigateToChat(withMessageId: messageId)
        }
        
        print("Notification received with userInfo: \(userInfo)")
        completionHandler()
    }

    // Handle token refresh
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(fcmToken ?? "")")
        // If necessary, send the token to your server
    }

    // Custom function to navigate to a specific chat/message when a notification is tapped
    private func navigateToChat(withMessageId messageId: String) {
        // Implement navigation logic here
        // For example, trigger a deep link or send a notification within the app to open the chat screen
    }

    // Handle silent notifications for background fetches or data updates
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Check if this is a silent notification
        if let contentAvailable = userInfo["content-available"] as? Int, contentAvailable == 1 {
            // Fetch data silently and update the app
            fetchNewData { result in
                completionHandler(result)
            }
        } else {
            // Otherwise, handle it like a regular notification
            print("Regular notification received: \(userInfo)")
            completionHandler(.noData)
        }
    }
    
    private func fetchNewData(completion: @escaping (UIBackgroundFetchResult) -> Void) {
        // Implement data fetching logic
        // For example, you could call a function that updates the unread message count or fetches new data
        completion(.newData)
    }
}
