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
    @Binding var isShowingLoginView: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var userName = ""
    @State private var errorMessage = ""
    @State private var showAlert = false
    @State private var isUsernameStep = false
    @State private var emailVerificationSent = false
    @State private var verificationTimer: Timer?

    // Focus states for managing keyboard focus
    @FocusState private var emailFieldIsFocused: Bool
    @FocusState private var passwordFieldIsFocused: Bool
    @FocusState private var confirmPasswordFieldIsFocused: Bool
    @FocusState private var usernameFieldIsFocused: Bool

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.02, green: 0.18, blue: 0.15),
                    Color(red: 0.21, green: 0.29, blue: 0.40)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            VStack {
                Spacer()

                Text(isUsernameStep ? "Choose a Username" : "Sign Up")
                    .font(.custom("AvenirNext-Bold", size: 36))
                    .foregroundColor(Color(red: 0.98, green: 0.27, blue: 0.29))
                    .padding(.bottom, 40)
                    .shadow(
                        color: Color(red: 0.86, green: 0.24, blue: 0.29),
                        radius: 10, x: 0, y: 5
                    )

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
                                    .stroke(
                                        Color(red: 0.86, green: 0.24, blue: 0.29),
                                        lineWidth: 1.0
                                    )
                            )
                            .padding(.bottom, 20)
                            .focused($usernameFieldIsFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                usernameFieldIsFocused = false
                            }
                    } else {
                        // Email input
                        Text("Email")
                            .foregroundColor(.white)
                            .font(.headline)
                        TextField("Enter your email", text: $email)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .padding()
                            .background(Color(.systemGray6).opacity(0.8))
                            .cornerRadius(8.0)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8.0)
                                    .stroke(
                                        Color(red: 0.86, green: 0.24, blue: 0.29),
                                        lineWidth: 1.0
                                    )
                            )
                            .padding(.bottom, 20)
                            .focused($emailFieldIsFocused)
                            .submitLabel(.next)
                            .onSubmit {
                                emailFieldIsFocused = false
                                passwordFieldIsFocused = true
                            }

                        // Password input
                        Text("Password")
                            .foregroundColor(.white)
                            .font(.headline)
                        SecureField("Enter your password", text: $password)
                            .padding()
                            .background(Color(.systemGray6).opacity(0.8))
                            .cornerRadius(8.0)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8.0)
                                    .stroke(
                                        Color(red: 0.86, green: 0.24, blue: 0.29),
                                        lineWidth: 1.0
                                    )
                            )
                            .padding(.bottom, 20)
                            .focused($passwordFieldIsFocused)
                            .submitLabel(.next)
                            .onSubmit {
                                passwordFieldIsFocused = false
                                confirmPasswordFieldIsFocused = true
                            }

                        // Confirm password input
                        Text("Confirm Password")
                            .foregroundColor(.white)
                            .font(.headline)
                        SecureField("Confirm your password", text: $confirmPassword)
                            .padding()
                            .background(Color(.systemGray6).opacity(0.8))
                            .cornerRadius(8.0)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8.0)
                                    .stroke(
                                        Color(red: 0.86, green: 0.24, blue: 0.29),
                                        lineWidth: 1.0
                                    )
                            )
                            .padding(.bottom, 20)
                            .focused($confirmPasswordFieldIsFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                confirmPasswordFieldIsFocused = false
                            }
                    }
                }
                .padding(.horizontal, 30)

                Button(action: {
                    // Dismiss the keyboard when the button is pressed
                    emailFieldIsFocused = false
                    passwordFieldIsFocused = false
                    confirmPasswordFieldIsFocused = false
                    usernameFieldIsFocused = false

                    if isUsernameStep {
                        checkEmailVerificationAndProceed()
                    } else {
                        validateEmailPassword()
                    }
                }) {
                    Text(isUsernameStep ? "Submit Username" : "Next")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 220, height: 60)
                        .background(Color(red: 0.98, green: 0.27, blue: 0.29))
                        .cornerRadius(15.0)
                        .shadow(
                            color: Color(red: 0.98, green: 0.27, blue: 0.29).opacity(0.5),
                            radius: 10, x: 0, y: 10
                        )
                }
                .padding(.top, 20)
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text("Notice"),
                        message: Text(errorMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }

                if emailVerificationSent && !isUsernameStep {
                    Text("""
                    A verification email has been sent to \(email).
                    Please verify your email before proceeding.
                    """)
                    .foregroundColor(.white)
                    .padding()
                    .multilineTextAlignment(.center)
                }

                Spacer()

                HStack {
                    Text("Already have an account?")
                        .foregroundColor(.white)
                    Button(action: {
                        isShowingLoginView = true  // Switch to LoginView
                    }) {
                        Text("Log In")
                            .foregroundColor(Color(red: 0.98, green: 0.27, blue: 0.29))
                            .fontWeight(.bold)
                    }
                }
                .padding(.bottom, 30)
            }
            .onDisappear {
                verificationTimer?.invalidate()
            }
        }
    }

    // Functions (inside the View) such as validateEmailPassword, submitUsername, etc.

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

        // Create a new account and send verification email
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                errorMessage = error.localizedDescription
                showAlert = true
                return
            }

            // Send verification email
            if let user = Auth.auth().currentUser {
                user.sendEmailVerification { error in
                    if let error = error {
                        errorMessage = "Error sending verification email: \(error.localizedDescription)"
                        showAlert = true
                        return
                    }

                    emailVerificationSent = true
                    startVerificationCheckTimer()
                }
            }
        }
    }

    func startVerificationCheckTimer() {
        verificationTimer?.invalidate() // Invalidate any existing timer
        verificationTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            checkEmailVerification()
        }
    }

    func checkEmailVerification() {
        Auth.auth().currentUser?.reload { _ in
            if Auth.auth().currentUser?.isEmailVerified == true {
                verificationTimer?.invalidate() // Stop checking
                isUsernameStep = true // Proceed to the username step
                emailVerificationSent = false  // Hide the verification message
            }
        }
    }

    func checkEmailVerificationAndProceed() {
        Auth.auth().currentUser?.reload { _ in
            if Auth.auth().currentUser?.isEmailVerified == true {
                submitUsername()
            } else {
                errorMessage = "Please verify your email before proceeding."
                showAlert = true
            }
        }
    }

    func submitUsername() {
        let db = Firestore.firestore()

        // Check if the username is already taken
        let usernameQuery = db.collection("users").whereField("name", isEqualTo: userName)

        usernameQuery.getDocuments { (snapshot, error) in
            if let error = error {
                errorMessage = "Error checking username: \(error.localizedDescription)"
                showAlert = true
                return
            }

            if snapshot?.isEmpty == false {
                errorMessage = "Username is already in use"
                showAlert = true
                return
            }

            // Save the username and user data to Firestore
            guard let uid = Auth.auth().currentUser?.uid else {
                errorMessage = "Failed to retrieve user ID."
                showAlert = true
                return
            }

            let userData: [String: Any] = [
//                "id": uid,
                "name": userName,
                "email": email,
                "rank": "Unranked",
                "imageName": "default",
                "age": "Unknown",
                "server": "Unknown",
                "answers": [:],
                "hasAnsweredQuestions": false,
                "mediaItems": [],
                "createdAt": Timestamp(), // Add timestamp
                "interactedUsers": [], // Initialize as empty
                "hasSeenTutorial": false // Ensure tutorial step is tracked
            ]

            db.collection("users").document(uid).setData(userData) { error in
                if let error = error {
                    errorMessage = "Error saving user data: \(error.localizedDescription)"
                    showAlert = true
                    return
                }

                print("DEBUG: New user profile created successfully.")

                // After the user is created, navigate to the login view
                isSignedIn = false  // Force user to log in again
                isShowingLoginView = true  // Navigate to login after sign-up
            }
        }
    }

}



struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView(
            currentUser: .constant(nil),
            isSignedIn: .constant(false),
            isShowingLoginView: .constant(false)
        )
    }
}
