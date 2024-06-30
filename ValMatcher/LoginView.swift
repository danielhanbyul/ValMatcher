//
//  LoginView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/7/24.
//

import SwiftUI

struct LoginView: View {
    @Binding var currentUser: UserProfile?
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false

    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                
                Text("ValMatcher")
                    .font(.custom("AvenirNext-Bold", size: 48)) // Using a built-in font
                    .foregroundColor(Color(red: 0.98, green: 0.27, blue: 0.29)) // #na4454 equivalent
                    .padding(.bottom, 40)
                    .shadow(color: Color(red: 0.86, green: 0.24, blue: 0.29), radius: 10, x: 0, y: 5) // #dc3d4b equivalent

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
                                .stroke(Color(red: 0.86, green: 0.24, blue: 0.29), lineWidth: 1.0) // #dc3d4b equivalent
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
                                .stroke(Color(red: 0.86, green: 0.24, blue: 0.29), lineWidth: 1.0) // #dc3d4b equivalent
                        )
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)

                Button(action: {
                    // Handle login action
                }) {
                    Text("Log In")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 220, height: 60)
                        .background(Color(red: 0.98, green: 0.27, blue: 0.29)) // #na4454 equivalent
                        .cornerRadius(15.0)
                        .shadow(color: Color(red: 0.98, green: 0.27, blue: 0.29).opacity(0.5), radius: 10, x: 0, y: 10) // #na4454 equivalent
                }
                .padding(.top, 20)

                Spacer()

                HStack {
                    Text("Don't have an account?")
                        .foregroundColor(.white)
                    Button(action: {
                        self.showingSignUp.toggle()
                    }) {
                        Text("Sign Up")
                            .foregroundColor(Color(red: 0.98, green: 0.27, blue: 0.29)) // #na4454 equivalent
                            .fontWeight(.bold)
                    }
                    .sheet(isPresented: $showingSignUp) {
                        SignUpView(currentUser: $currentUser)
                    }
                }
                .padding(.bottom, 30)

            }
            .background(
                LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom) // #042e27 and #364966 equivalent
                    .edgesIgnoringSafeArea(.all)
            )
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    @State static var currentUser: UserProfile? = nil

    static var previews: some View {
        LoginView(currentUser: $currentUser)
            .preferredColorScheme(.dark) // Assuming dark mode preference
    }
}
