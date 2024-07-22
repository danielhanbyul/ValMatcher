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

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            VStack {
                Spacer()

                Text("Sign Up")
                    .font(.custom("AvenirNext-Bold", size: 36))
                    .foregroundColor(Color(red: 0.98, green: 0.27, blue: 0.29))
                    .padding(.bottom, 40)
                    .shadow(color: Color(red: 0.86, green: 0.24, blue: 0.29), radius: 10, x: 0, y: 5)

                VStack(alignment: .leading, spacing: 15) {
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
                .padding(.horizontal, 30)

                Button(action: signUp) {
                    Text("Sign Up")
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
                    Alert(title: Text("Success"), message: Text("Your account has been created. Please log in."), dismissButton: .default(Text("OK")) {
                        isShowingLoginView = true
                    })
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

    func signUp() {
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            showAlert = true
            return
        }

        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                self.errorMessage = "Error: \(error.localizedDescription)"
                self.showAlert = true
                print("Error creating user: \(error.localizedDescription)")
                return
            }

            guard let uid = authResult?.user.uid else {
                self.errorMessage = "Failed to retrieve user ID."
                self.showAlert = true
                return
            }

            let db = Firestore.firestore()
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
                    print("Error saving user data: \(error.localizedDescription)")
                    return
                }
                self.showAlert = true
            }
        }
    }
}

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView(currentUser: .constant(nil), isSignedIn: .constant(false), isShowingLoginView: .constant(false))
    }
}
