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
    @Binding var isShowingLoginView: Bool

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
            isShowingLoginView = true
        } catch let signOutError as NSError {
            print("Error signing out: \(signOutError.localizedDescription)")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(user: .constant(UserProfile(id: "", name: "", rank: "", imageName: "", age: "", server: "", answers: [:], hasAnsweredQuestions: false, additionalImages: [])), isSignedIn: .constant(true), isShowingLoginView: .constant(false))
    }
}
