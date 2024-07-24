//
//  ValMatcherApp.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/6/24.
//

import SwiftUI
import Firebase
import UserNotifications

@main
struct ValMatcherApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            MainView()  // Ensure MainView is used here for handling navigation
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    override init() {
        super.init()
        // Register for remote notifications
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            print("Notification permission granted: \(granted)")
            if let error = error {
                print("Error requesting notification permissions: \(error.localizedDescription)")
            }
        }
        UNUserNotificationCenter.current().delegate = self
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        application.registerForRemoteNotifications()  // Register for remote notifications
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken  // Set the APNs token for Firebase
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // Handle notifications when the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
    }

    // Handle notification tap action
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        // Handle the notification data here
        print("Notification received with userInfo: \(userInfo)")
        completionHandler()
    }
}
