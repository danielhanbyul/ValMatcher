//
//  ProfileView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/15/24.
//

import SwiftUI
import Firebase

struct ProfileView: View {
    @ObservedObject var viewModel: UserProfileViewModel
    @Binding var isSignedIn: Bool
    @Environment(\.presentationMode) var presentationMode
    @State private var isEditing = false
    @State private var showingImagePicker = false
    @State private var newMedia: [MediaItem] = []
    @State private var newAge = ""
    @State private var newRank = ""
    @State private var newServer = ""
    @State private var additionalImages: [String] = []
    @State private var updatedAnswers: [String: String] = [:]
    @State private var showingSettings = false
    @State private var isShowingLoginView = false

    var body: some View {
        VStack {
            // Custom Navigation Bar
            HStack {
                Button(action: {
                    if isEditing {
                        isEditing.toggle()
                    } else {
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .imageScale(.medium)
                }
                
                Spacer()
                
                Text("Profile")
                    .foregroundColor(.white)
                    .font(.custom("AvenirNext-Bold", size: 20))
                
                Spacer()
                
                if !isEditing && viewModel.user.id == Auth.auth().currentUser?.uid {
                    Button(action: {
                        isEditing.toggle()
                        initializeEditValues()
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.white)
                            .imageScale(.medium)
                    }
                }
                
                Button(action: {
                    showingSettings.toggle()
                }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.white)
                        .imageScale(.medium)
                }
            }
            .padding()
            .background(Color.black)
            .frame(height: 44)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    UserCardView(user: viewModel.user, newMedia: newMedia)
                    
                    if isEditing {
                        Button(action: {
                            self.showingImagePicker = true
                        }) {
                            Text("Add Images/Videos")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        if isEditing {
                            TextField("Age", text: $newAge)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                            TextField("Rank", text: $newRank)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                            TextField("Server", text: $newServer)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                        } else {
                            Text("\(viewModel.user.name), \(viewModel.user.age)")
                                .font(.custom("AvenirNext-Bold", size: 28))
                                .foregroundColor(.white)
                            
                            Text("Rank: \(viewModel.user.rank)")
                                .font(.custom("AvenirNext-Regular", size: 18))
                                .foregroundColor(.gray)
                            
                            Text("Server: \(viewModel.user.server)")
                                .font(.custom("AvenirNext-Regular", size: 18))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)

                    Divider()
                        .background(Color.gray)

                    VStack(alignment: .leading, spacing: 15) {
                        ForEach(viewModel.user.answers.keys.sorted(), id: \.self) { question in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(question)
                                    .font(.custom("AvenirNext-Bold", size: 20))
                                    .foregroundColor(.white)
                                if isEditing {
                                    TextField("Answer", text: Binding(
                                        get: { updatedAnswers[question] ?? viewModel.user.answers[question] ?? "" },
                                        set: { updatedAnswers[question] = $0 }
                                    ))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                } else {
                                    Text(viewModel.user.answers[question] ?? "No answer provided")
                                        .font(.custom("AvenirNext-Regular", size: 18))
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.bottom, 10)
                        }
                    }
                    .padding(.horizontal)
                    
                    if isEditing {
                        Button(action: saveProfile) {
                            Text("Save")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .padding(.top, 20)
                    }
                }
                .padding()
            }
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
        )
        .navigationBarTitle("", displayMode: .inline)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedMedia: $newMedia)
                .onDisappear(perform: {
                    // Navigate to ProfileView and refresh
                    DispatchQueue.main.async {
                        self.isEditing = false
                        saveProfile()
                    }
                })
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(user: $viewModel.user, isSignedIn: $isSignedIn, isShowingLoginView: $isShowingLoginView)
        }
        .fullScreenCover(isPresented: $isShowingLoginView) {
            LoginView(isSignedIn: $isSignedIn, currentUser: .constant(nil), isShowingLoginView: $isShowingLoginView)
        }
        .onAppear {
            initializeEditValues()
        }
    }

    private func initializeEditValues() {
        newAge = viewModel.user.age
        newRank = viewModel.user.rank
        newServer = viewModel.user.server
        additionalImages = viewModel.user.additionalImages.compactMap { $0 }
        updatedAnswers = viewModel.user.answers
    }

    private func saveProfile() {
        viewModel.updateUserProfile(
            newAge: newAge,
            newRank: newRank,
            newServer: newServer,
            additionalImages: additionalImages + newMedia.compactMap { $0.image != nil ? UIImageToDataURL(image: $0.image!)! : "" },
            updatedAnswers: updatedAnswers
        )
        isEditing.toggle()
    }
}
