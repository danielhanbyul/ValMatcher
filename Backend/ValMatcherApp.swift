//
//  ValMatcherApp.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/6/24.
//

import SwiftUI
import Firebase

import SwiftUI
import Firebase

@main
struct ValMatcherApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}


class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        return true
    }
}
