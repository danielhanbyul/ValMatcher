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
                        // Display existing images with delete buttons
                        HStack(spacing: 15) {
                            ForEach(additionalImages.indices, id: \.self) { index in
                                let urlString = additionalImages[index]
                                if let url = URL(string: urlString) {
                                    ZStack(alignment: .topTrailing) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView()
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 100, height: 100)
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 2))
                                                    .shadow(radius: 5)
                                            case .failure:
                                                Image(systemName: "photo")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 100, height: 100)
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 2))
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }

                                        // Delete button
                                        Button(action: {
                                            deleteImage(at: index)
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                                .padding(4)
                                                .background(Color.white)
                                                .clipShape(Circle())
                                                .shadow(radius: 3)
                                        }
                                        .offset(x: -10, y: 10)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

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
            // Ensure only a maximum of 3 images are saved, by adding only as many images as needed
            let remainingSlots = max(3 - self.additionalImages.count, 0)
            let imagesToAdd = urls.prefix(remainingSlots)
            self.additionalImages.append(contentsOf: imagesToAdd)
            
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
        uploadNewMedia { urls in
            // Ensure only a maximum of 3 images are saved, by adding only as many images as needed
            let remainingSlots = max(3 - self.additionalImages.count, 0)
            let imagesToAdd = urls.prefix(remainingSlots)
            self.additionalImages.append(contentsOf: imagesToAdd)
            
            self.viewModel.updateUserProfile(
                newAge: self.newAge,
                newRank: self.newRank,
                newServer: self.newServer,
                additionalImages: self.additionalImages.prefix(3).map { $0 },  // Ensure only 3 images are saved
                updatedAnswers: self.updatedAnswers
            )
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
                let metadata = StorageMetadata()
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
    
    private func deleteImage(at index: Int) {
        let urlString = additionalImages[index]
        additionalImages.remove(at: index)

        // Optionally, remove the image from Firebase Storage
        let storageRef = Storage.storage().reference(forURL: urlString)
        storageRef.delete { error in
            if let error = error {
                print("Error deleting image from storage: \(error.localizedDescription)")
            } else {
                print("Image deleted from storage")
            }
        }

        // No need to toggle editing, keep the user in edit mode
        saveProfile()
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
