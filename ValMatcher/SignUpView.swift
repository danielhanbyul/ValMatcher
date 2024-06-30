//
//  SignUpView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/7/24.
//

import SwiftUI
import Firebase

struct SignUpView: View {
    @Binding var currentUser: UserProfile?
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var userName = ""
    @State private var errorMessage = ""
    @State private var isProfileSetupPresented = false

    var body: some View {
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
            .alert(isPresented: .constant(!errorMessage.isEmpty)) {
                Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }

            Spacer()
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
        )
        .sheet(isPresented: $isProfileSetupPresented) {
            ProfileSetupView()
        }
    }

    func signUp() {
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }

        NetworkManager.shared.registerUser(userName: userName, email: email, password: password) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let token):
                    // Handle successful registration (store token if needed)
                    print("User registered with token: \(token)")
                    currentUser = UserProfile(name: userName, rank: "Unranked", imageName: "default", age: "Unknown", server: "Unknown", bestClip: "none", answers: [:], hasAnsweredQuestions: false)
                    isProfileSetupPresented = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct SignUpView_Previews: PreviewProvider {
    @State static var currentUser: UserProfile? = nil

    static var previews: some View {
        SignUpView(currentUser: $currentUser)
            .preferredColorScheme(.dark)
    }
}
