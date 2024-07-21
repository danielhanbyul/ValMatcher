//
//  ProfileView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/15/24.
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @Binding var user: UserProfile
    @Binding var isSignedIn: Bool
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            // Custom Back Button
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .imageScale(.medium)
                        Text("Back")
                            .foregroundColor(.white)
                            .font(.custom("AvenirNext-Bold", size: 18))
                    }
                }
                .padding(.top, 20)
                .padding(.leading, 20)
                
                Spacer()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Profile Picture
                    HStack {
                        Image(systemName: "person.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 150, height: 150)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 4))
                            .shadow(radius: 10)
                            .padding(.top, 20)
                            .padding(.bottom, 10)
                        
                        Spacer()
                    }
                    .padding(.horizontal)

                    // User Information
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(user.name), \(user.age)")
                            .font(.custom("AvenirNext-Bold", size: 28))
                            .foregroundColor(.white)
                        
                        Text("Rank: \(user.rank)")
                            .font(.custom("AvenirNext-Regular", size: 18))
                            .foregroundColor(.gray)
                        
                        Text("Server: \(user.server)")
                            .font(.custom("AvenirNext-Regular", size: 18))
                            .foregroundColor(.gray)
                        
                    }
                    .padding(.horizontal)

                    Divider()
                        .background(Color.gray)

                    // User Answers
                    VStack(alignment: .leading, spacing: 15) {
                        ForEach(user.answers.keys.sorted(), id: \.self) { question in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(question)
                                    .font(.custom("AvenirNext-Bold", size: 20))
                                    .foregroundColor(.white)
                                Text(user.answers[question] ?? "No answer provided")
                                    .font(.custom("AvenirNext-Regular", size: 18))
                                    .foregroundColor(.gray)
                            }
                            .padding(.bottom, 10)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
        )
        .navigationBarTitle("Profile", displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .imageScale(.medium)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: SettingsView(user: $user, isSignedIn: $isSignedIn)) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.white)
                        .imageScale(.medium)
                }
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView(user: .constant(UserProfile(
            name: "John Doe",
            rank: "Platinum 1",
            imageName: "john",
            age: "25",
            server: "NA",
            answers: [
                "Who's your favorite agent to play in Valorant?": "Jett",
                "Do you prefer playing as a Duelist, Initiator, Controller, or Sentinel?": "Duelist",
                "What’s your current rank in Valorant?": "Platinum",
                "Favorite game mode?": "Competitive",
                "What servers do you play on? (ex: NA, N. California)": "NA",
                "What's your favorite weapon skin in Valorant?": "Oni Phantom"
            ]
        )), isSignedIn: .constant(true))
        .preferredColorScheme(.dark)
    }
}
