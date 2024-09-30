//
//  SignUpView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/7/24.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct SignUpView: View {
    @Binding var currentUser: UserProfile?
    @Binding var isSignedIn: Bool
    @Binding var isShowingLoginView: Bool // Track whether to show Login or Signup view

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var userName = ""
    @State private var errorMessage = ""
    @State private var showAlert = false
    @State private var isUsernameStep = false // Track whether to show the username input step

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            VStack {
                Spacer()

                Text(isUsernameStep ? "Choose a Username" : "Sign Up")
                    .font(.custom("AvenirNext-Bold", size: 36))
                    .foregroundColor(Color(red: 0.98, green: 0.27, blue: 0.29))
                    .padding(.bottom, 40)
                    .shadow(color: Color(red: 0.86, green: 0.24, blue: 0.29), radius: 10, x: 0, y: 5)

                VStack(alignment: .leading, spacing: 15) {
                    if isUsernameStep {
                        // Username input step
                        Text("Username")
                            .foregroundColor(.white)
                            .font(.headline)
                        TextField("Enter your username", text: $userName)
                            .padding()
                            .background(Color(.systemGray6).opacity(0.8))
                            .cornerRadius(8.0)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8.0)
                                    .stroke(Color(red: 0.86, green: 0.24, blue: 0.29), lineWidth: 1.0)
                            )
                            .padding(.bottom, 20)
                    } else {
                        // Email and password input step
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
                            .padding(.bottom, 20)

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
                            .padding(.bottom, 20)

                        Text("Confirm Password")
                            .foregroundColor(.white)
                            .font(.headline)
                        SecureField("Confirm your password", text: $confirmPassword)
                            .padding()
                            .background(Color(.systemGray6).opacity(0.8))
                            .cornerRadius(8.0)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8.0)
                                    .stroke(Color(red: 0.86, green: 0.24, blue: 0.29), lineWidth: 1.0)
                            )
                            .padding(.bottom, 20)
                    }
                }
                .padding(.horizontal, 30)

                Button(action: {
                    isUsernameStep ? submitUsername() : validateEmailPassword()
                }) {
                    Text(isUsernameStep ? "Submit Username" : "Next")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 220, height: 60)
                        .background(Color(red: 0.98, green: 0.27, blue: 0.29))
                        .cornerRadius(15.0)
                        .shadow(color: Color(red: 0.98, green: 0.27, blue: 0.29).opacity(0.5), radius: 10, x: 0, y: 10)
                }
                .padding(.top, 20)
                .alert(isPresented: $showAlert) {
                    Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
                }

                Spacer()

                HStack {
                    Text("Already have an account?")
                        .foregroundColor(.white)
                    Button(action: {
                        isShowingLoginView = true
                    }) {
                        Text("Log In")
                            .foregroundColor(Color(red: 0.98, green: 0.27, blue: 0.29))
                            .fontWeight(.bold)
                    }
                }
                .padding(.bottom, 30)
            }
        }
    }

    // Step 1: Validate email and password
    func validateEmailPassword() {
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            showAlert = true
            return
        }

        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            showAlert = true
            return
        }

        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error as NSError? {
                let authError = AuthErrorCode(_nsError: error)
                switch authError.code {
                case .emailAlreadyInUse:
                    self.errorMessage = "This email is already in use."
                case .invalidEmail:
                    self.errorMessage = "Invalid email format."
                case .weakPassword:
                    self.errorMessage = "Password is too weak."
                default:
                    self.errorMessage = "Error: \(error.localizedDescription)"
                }
                self.showAlert = true
                return
            }

            // If email and password are valid, move to username step
            self.isUsernameStep = true
        }
    }

    // Step 2: Submit and validate username
    func submitUsername() {
        let db = Firestore.firestore()

        // Check if username is already taken
        let usernameQuery = db.collection("users").whereField("name", isEqualTo: userName)

        usernameQuery.getDocuments { (snapshot, error) in
            if let error = error {
                self.errorMessage = "Error checking username: \(error.localizedDescription)"
                self.showAlert = true
                return
            }

            if snapshot?.isEmpty == false {
                self.errorMessage = "Username is already in use"
                self.showAlert = true
                return
            }

            // Save the username to Firestore
            guard let uid = Auth.auth().currentUser?.uid else {
                self.errorMessage = "Failed to retrieve user ID."
                self.showAlert = true
                return
            }

            let userData: [String: Any] = [
                "name": userName,
                "email": email,
                "rank": "Unranked",
                "imageName": "default",
                "age": "Unknown",
                "server": "Unknown",
                "answers": [:],
                "hasAnsweredQuestions": false,
                "additionalImages": []
            ]

            db.collection("users").document(uid).setData(userData) { error in
                if let error = error {
                    self.errorMessage = "Error saving user data: \(error.localizedDescription)"
                    self.showAlert = true
                    return
                }

                // Account created successfully
                self.errorMessage = "Your account has been created. Please log in."
                self.showAlert = true
                isShowingLoginView = true
            }
        }
    }
}

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView(currentUser: .constant(nil), isSignedIn: .constant(false), isShowingLoginView: .constant(false))
    }
}
