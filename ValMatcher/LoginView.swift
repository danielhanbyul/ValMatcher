//
//  LoginView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/7/24.
//

import SwiftUI
import Firebase

struct LoginView: View {
    @Binding var currentUser: UserProfile?
    @Binding var isSignedIn: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false
    @State private var errorMessage = ""

    var body: some View {
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
                    self.showingSignUp.toggle()
                }) {
                    Text("Sign Up")
                        .foregroundColor(Color(red: 0.98, green: 0.27, blue: 0.29))
                        .fontWeight(.bold)
                }
                .sheet(isPresented: $showingSignUp) {
                    SignUpView(currentUser: $currentUser, isSignedIn: $isSignedIn)
                }
            }
            .padding(.bottom, 30)
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
        )
    }

    func signIn() {
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                self.errorMessage = "Error: \(error.localizedDescription)"
                print("Error signing in: \(error.localizedDescription)")
                return
            }
            // Handle successful sign-in
            self.isSignedIn = true
            fetchUserProfile()
        }
    }

    func fetchUserProfile() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { document, error in
            if let document = document, document.exists {
                if let data = document.data() {
                    self.currentUser = UserProfile(
                        id: document.documentID,
                        name: data["name"] as? String ?? "",
                        rank: data["rank"] as? String ?? "",
                        imageName: data["imageName"] as? String ?? "",
                        age: data["age"] as? String ?? "",
                        server: data["server"] as? String ?? "",
                        bestClip: data["bestClip"] as? String ?? "",
                        answers: data["answers"] as? [String: String] ?? [:],
                        hasAnsweredQuestions: data["hasAnsweredQuestions"] as? Bool ?? false,
                        media: data["media"] as? [String] ?? []
                    )
                }
            } else {
                if let error = error {
                    self.errorMessage = "Error fetching user profile: \(error.localizedDescription)"
                    print("Error fetching user profile: \(error.localizedDescription)")
                } else {
                    self.errorMessage = "User profile does not exist."
                    print("User profile does not exist.")
                }
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    @State static var currentUser: UserProfile? = nil
    @State static var isSignedIn = false

    static var previews: some View {
        LoginView(currentUser: $currentUser, isSignedIn: $isSignedIn)
            .preferredColorScheme(.dark)
    }
}
