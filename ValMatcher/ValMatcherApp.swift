//
//  ValMatcherApp.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/6/24.
//

import SwiftUI

@main
struct ValMatcherApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// Utility.swift
import Foundation

func isPreview() -> Bool {
    return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}
