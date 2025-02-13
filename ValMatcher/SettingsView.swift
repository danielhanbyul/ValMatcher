//
//  SettingsView.swift
//  ValMatcher
//
//  Created by Daniel Han on 7/20/24.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SettingsView: View {
    @Binding var user: UserProfile
    @Binding var isSignedIn: Bool
    @Binding var isShowingLoginView: Bool
    @State private var showDeleteConfirmation = false // Controls delete account alert

    var body: some View {
        VStack {
            List {
                Section {
                    Button(action: {
                        logout()
                    }) {
                        Text("Logout")
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Text("Delete Account")
                            .foregroundColor(.red)
                    }
                    .alert(isPresented: $showDeleteConfirmation) {
                        Alert(
                            title: Text("Delete Account"),
                            message: Text("Are you sure you want to delete your account? This action cannot be undone."),
                            primaryButton: .destructive(Text("Delete")) {
                                deleteAccount() // Calls the delete function
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("Settings", displayMode: .inline)
        }
    }

    // MARK: - Logout Function
    private func logout() {
        do {
            try Auth.auth().signOut()
            isSignedIn = false
            isShowingLoginView = true
            print("DEBUG: User logged out successfully.")
        } catch let signOutError as NSError {
            print("ERROR: Failed to log out: \(signOutError.localizedDescription)")
        }
    }

    // MARK: - Delete Account Function
    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else {
            print("DEBUG: No authenticated user to delete.")
            return
        }

        let userId = user.uid
        let db = Firestore.firestore()

        // Step 1: Remove FCM Token from Firestore before deletion
        db.collection("users").document(userId).updateData(["fcmToken": FieldValue.delete()]) { tokenError in
            if let tokenError = tokenError {
                print("ERROR: Failed to remove FCM token: \(tokenError.localizedDescription)")
            } else {
                print("DEBUG: Successfully removed FCM token.")
            }

            // Step 2: Delete the Firestore user document
            db.collection("users").document(userId).delete { firestoreError in
                if let firestoreError = firestoreError {
                    print("ERROR: Failed to delete user data: \(firestoreError.localizedDescription)")
                    return
                }
                print("DEBUG: User document deleted from Firestore.")

                // Step 3: Delete the Firebase Authentication account
                user.delete { authError in
                    if let authError = authError {
                        print("ERROR: Failed to delete Firebase Auth account: \(authError.localizedDescription)")
                        return
                    }
                    print("DEBUG: Firebase Auth account deleted.")

                    // Step 4: Log out and redirect to login screen
                    DispatchQueue.main.async {
                        isSignedIn = false
                        isShowingLoginView = true
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            user: .constant(UserProfile(
                id: "",
                name: "",
                rank: "",
                imageName: "",
                age: 0, // Default integer value
                server: "",
                answers: [:],
                hasAnsweredQuestions: false,
                mediaItems: []
            )),
            isSignedIn: .constant(true),
            isShowingLoginView: .constant(false)
        )
    }
}
