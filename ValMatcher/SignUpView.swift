//
//  SignUpView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/7/24.
//

import SwiftUI

struct SignUpView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var userName = ""

    var body: some View {
        VStack {
            Spacer()
            Text("Sign Up")
                .font(.custom("AvenirNext-Bold", size: 36)) // Using the custom font
                .foregroundColor(Color(red: 0.98, green: 0.27, blue: 0.29)) // #na4454 equivalent
                .padding(.bottom, 40)
                .shadow(color: Color(red: 0.86, green: 0.24, blue: 0.29), radius: 10, x: 0, y: 5) // #dc3d4b equivalent

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
                            .stroke(Color(red: 0.86, green: 0.24, blue: 0.29), lineWidth: 1.0) // #dc3d4b equivalent
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
                            .stroke(Color(red: 0.86, green: 0.24, blue: 0.29), lineWidth: 1.0) // #dc3d4b equivalent
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
                            .stroke(Color(red: 0.86, green: 0.24, blue: 0.29), lineWidth: 1.0) // #dc3d4b equivalent
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
                            .stroke(Color(red: 0.86, green: 0.24, blue: 0.29), lineWidth: 1.0) // #dc3d4b equivalent
                    )
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 30)

            Button(action: {
                // Handle sign up action
            }) {
                Text("Sign Up")
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
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom) // #042e27 and #364966 equivalent
                .edgesIgnoringSafeArea(.all)
        )
    }
}

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
            .preferredColorScheme(.dark) // Assuming dark mode preference
    }
}
