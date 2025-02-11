//
//  LoginView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/7/24.
//

import SwiftUI
import Firebase

struct LoginView: View {
    @Binding var isSignedIn: Bool
    @Binding var currentUser: UserProfile?
    @Binding var isShowingLoginView: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            VStack {
                Spacer()

                Text("ValMatcher")
                    .font(.custom("AvenirNext-Bold", size: 48))
                    .foregroundColor(Color(red: 0.98, green: 0.27, blue: 0.29))
                    .padding(.bottom, 40)
                    .shadow(color: Color(red: 0.86, green: 0.24, blue: 0.29), radius: 10, x: 0, y: 5)

                VStack(alignment: .leading, spacing: 15) {
                    Text("Email")
                        .foregroundColor(.white)
                        .font(.headline)
                    
                    TextField("Enter your email", text: $email)
                        .padding()
                        .background(Color(.systemGray6).opacity(0.8))
                        .cornerRadius(8.0)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8.0)
                                .stroke(Color(red: 0.86, green: 0.24, blue: 0.29), lineWidth: 1.0)
                        )

                    Text("Password")
                        .foregroundColor(.white)
                        .font(.headline)
                    
                    SecureField("Enter your password", text: $password)
                        .padding()
                        .background(Color(.systemGray6).opacity(0.8))
                        .cornerRadius(8.0)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8.0)
                                .stroke(Color(red: 0.86, green: 0.24, blue: 0.29), lineWidth: 1.0)
                        )
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)

                Button(action: {
                    signIn()
                }) {
                    Text("Log In")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 220, height: 60)
                        .background(Color(red: 0.98, green: 0.27, blue: 0.29))
                        .cornerRadius(15.0)
                        .shadow(color: Color(red: 0.98, green: 0.27, blue: 0.29).opacity(0.5), radius: 10, x: 0, y: 10)
                }
                .padding(.top, 20)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }

                Spacer()

                HStack {
                    Text("Don't have an account?")
                        .foregroundColor(.white)
                    Button(action: {
                        isShowingLoginView = false
                    }) {
                        Text("Sign Up")
                            .foregroundColor(Color(red: 0.98, green: 0.27, blue: 0.29))
                            .fontWeight(.bold)
                    }
                }
                .padding(.bottom, 30)
            }
        }
    }

    func signIn() {
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                self.errorMessage = "Error: \(error.localizedDescription)"
                print("Error signing in: \(error.localizedDescription)")
                return
            }
            
            isSignedIn = true
            if let user = authResult?.user {
                // Clear the current profile before fetching new one
                currentUser = nil
                fetchUserProfile(userID: user.uid) // Ensure new profile is fetched
            }
        }
    }

    // Sign out from Firebase
    func signOut() {
        do {
            try Auth.auth().signOut()
            isSignedIn = false
            currentUser = nil  // Reset the current user
            email = ""
            password = ""
            errorMessage = ""
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
            self.errorMessage = "Error: \(signOutError.localizedDescription)"
        }
    }

    func fetchUserProfile(userID: String) {
        let db = Firestore.firestore()
        db.collection("users").document(userID).getDocument { document, error in
            if let error = error {
                print("Error fetching user profile: \(error.localizedDescription)")
                self.errorMessage = "Error fetching user profile: \(error.localizedDescription)"
                return
            }

            if let document = document, document.exists, let data = document.data() {
                let mediaURLs = data["mediaItems"] as? [String] ?? []
                let mediaItems = mediaURLs.map { url in
                    return MediaItem(type: url.contains(".mp4") ? .video : .image, url: URL(string: url)!)
                }

                // Handling age safely, ensuring it's retrieved as an Int
                var userAge: Int = 0
                if let ageValue = data["age"] {
                    if let ageInt = ageValue as? Int {
                        userAge = ageInt
                    } else if let ageString = ageValue as? String, let ageConverted = Int(ageString) {
                        userAge = ageConverted
                    } else {
                        print("DEBUG: Invalid age format in Firestore")
                    }
                }

                DispatchQueue.main.async {
                    self.currentUser = UserProfile(
                        id: document.documentID,
                        name: data["name"] as? String ?? "",
                        rank: data["rank"] as? String ?? "",
                        imageName: data["imageName"] as? String ?? "",
                        age: userAge,  // Updated to use the safely converted age
                        server: data["server"] as? String ?? "",
                        answers: data["answers"] as? [String: String] ?? [:],
                        hasAnsweredQuestions: data["hasAnsweredQuestions"] as? Bool ?? false,
                        mediaItems: mediaItems
                    )
                }
            } else {
                self.errorMessage = "User profile does not exist."
            }
        }
    }

}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(isSignedIn: .constant(false), currentUser: .constant(nil), isShowingLoginView: .constant(true))
    }
}
