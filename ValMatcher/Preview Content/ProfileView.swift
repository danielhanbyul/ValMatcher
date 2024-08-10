//
//  ProfileView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/15/24.
//

import SwiftUI
import Firebase
import FirebaseStorage

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
                        .disabled(additionalImages.count + newMedia.count >= 3)  // Disable button after 3 images
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
                            Text("Save Profile")
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
                    saveMedia()
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
        uploadNewMedia { urls in
            self.additionalImages.append(contentsOf: urls)
            self.viewModel.updateUserProfile(
                newAge: self.newAge,
                newRank: self.newRank,
                newServer: self.newServer,
                additionalImages: self.additionalImages.prefix(3).map { $0 },  // Ensure only 3 images are saved
                updatedAnswers: self.updatedAnswers
            )
            self.isEditing.toggle()
        }
    }

    private func saveMedia() {
        // Handle media upload and save profile data
        uploadNewMedia { urls in
            self.additionalImages.append(contentsOf: urls)
            self.viewModel.updateUserProfile(
                newAge: self.newAge,
                newRank: self.newRank,
                newServer: self.newServer,
                additionalImages: self.additionalImages.prefix(3).map { $0 },  // Ensure only 3 images are saved
                updatedAnswers: self.updatedAnswers
            )
            self.isEditing.toggle()
        }
    }
    

    func uploadNewMedia(completion: @escaping ([String]) -> Void) {
        let dispatchGroup = DispatchGroup()
        var uploadedURLs: [String] = []

        for media in newMedia {
            dispatchGroup.enter()
            if let image = media.image {
                let fileName = UUID().uuidString + ".jpg"
                let storageRef = Storage.storage().reference().child("media/\(viewModel.user.id!)/\(fileName)")

                let imageData = image.jpegData(compressionQuality: 0.8)!
                let metadata = StorageMetadata() // Correctly initialize metadata if needed
                metadata.contentType = "image/jpeg"

                storageRef.putData(imageData, metadata: metadata) { metadata, error in
                    guard error == nil else {
                        print("Error uploading image: \(error!.localizedDescription)")
                        dispatchGroup.leave()
                        return
                    }

                    storageRef.downloadURL { url, error in
                        guard let downloadURL = url else {
                            print("Error getting download URL: \(error!.localizedDescription)")
                            dispatchGroup.leave()
                            return
                        }

                        uploadedURLs.append(downloadURL.absoluteString)
                        dispatchGroup.leave()
                    }
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            self.saveImageURLsToFirestore(uploadedURLs)
            completion(uploadedURLs)
        }
    }
    
    private func saveImageURLsToFirestore(_ urls: [String]) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(viewModel.user.id ?? "")
        userRef.updateData([
            "additionalImages": FieldValue.arrayUnion(urls)
        ]) { error in
            if let error = error {
                print("Error saving image URLs to Firestore: \(error.localizedDescription)")
            } else {
                print("Successfully saved image URLs to Firestore")
            }
        }
    }
}
