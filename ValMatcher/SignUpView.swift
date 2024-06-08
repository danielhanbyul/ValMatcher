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
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.red)
                .padding(.bottom, 40)

            VStack(alignment: .leading) {
                Text("Username")
                    .foregroundColor(.gray)
                TextField("Enter your username", text: $userName)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(5.0)
                    .shadow(radius: 5)
                    .padding(.bottom, 20)

                Text("Email")
                    .foregroundColor(.gray)
                TextField("Enter your email", text: $email)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(5.0)
                    .shadow(radius: 5)
                    .padding(.bottom, 20)

                Text("Password")
                    .foregroundColor(.gray)
                SecureField("Enter your password", text: $password)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(5.0)
                    .shadow(radius: 5)
                    .padding(.bottom, 20)

                Text("Confirm Password")
                    .foregroundColor(.gray)
                SecureField("Confirm your password", text: $confirmPassword)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(5.0)
                    .shadow(radius: 5)
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
                    .background(Color.red)
                    .cornerRadius(15.0)
                    .shadow(radius: 10)
            }
            .padding(.top, 20)

            Spacer()
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.black, Color.gray]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
        )
    }
}

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
    }
}
