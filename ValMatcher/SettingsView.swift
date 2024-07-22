//
//  SettingsView.swift
//  ValMatcher
//
//  Created by Daniel Han on 7/20/24.
//

import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @Binding var user: UserProfile
    @Binding var isSignedIn: Bool

    var body: some View {
        VStack {
            List {
                Button(action: {
                    logout()
                }) {
                    Text("Logout")
                        .foregroundColor(.red)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("Settings", displayMode: .inline)
        }
    }

    private func logout() {
        do {
            try Auth.auth().signOut()
            isSignedIn = false
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
        }
    }
}
