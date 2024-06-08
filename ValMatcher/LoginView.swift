//
//  LoginView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/7/24.
//

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false

    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                Text("ValMatcher")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                    .padding(.bottom, 40)

                VStack(alignment: .leading) {
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
                }
                .padding(.horizontal, 30)

                Button(action: {
                    // Handle login action
                }) {
                    Text("Log In")
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

                HStack {
                    Text("Don't have an account?")
                        .foregroundColor(.white)
                    Button(action: {
                        self.showingSignUp.toggle()
                    }) {
                        Text("Sign Up")
                            .foregroundColor(.red)
                            .fontWeight(.bold)
                    }
                    .sheet(isPresented: $showingSignUp) {
                        SignUpView()
                    }
                }
                .padding(.bottom, 30)

            }
            .background(
                LinearGradient(gradient: Gradient(colors: [Color.black, Color.gray]), startPoint: .top, endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all)
            )
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
