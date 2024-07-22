//
//  ProfileView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/15/24.
//

import SwiftUI

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
                    
                    // Display Additional Images
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Additional Images")
                            .font(.headline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(user.additionalImages.indices, id: \.self) { index in
                                    let urlString = user.additionalImages[index]
                                    if let url = URL(string: urlString),
                                       let data = try? Data(contentsOf: url),
                                       let image = UIImage(data: data) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 2))
                                            .shadow(radius: 5)
                                    }
                                }
                            }
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
