//
//  ProfileView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/15/24.
//

import SwiftUI
import Firebase
import FirebaseStorage
import AVKit

struct ProfileView: View {
    @ObservedObject var viewModel: UserProfileViewModel
    @Binding var isSignedIn: Bool
    @Environment(\.presentationMode) var presentationMode
    @State private var isEditing = false
    @State private var showingImagePicker = false
    @State private var newMedia: [MediaItem] = []
    @State private var additionalMedia: [MediaItem] = []
    @State private var updatedAnswers: [String: String] = [:]
    @State private var showingSettings = false
    @State private var isShowingLoginView = false
    @State private var selectedImages: Set<Int> = []
    @State private var currentIndex: Int = 0 // To track the current image being displayed

    let maxMediaCount = 3 // Maximum number of media items allowed

    var body: some View {
        VStack {
            HStack {
                backButton
                Spacer()
                titleText
                Spacer()
                editButton
                settingsButton
            }
            .padding()
            .background(Color.black)
            .frame(height: 44)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    UserCardView(user: viewModel.user)
                    
                    if isEditing {
                        editableMediaList
                        addMediaButton
                        deleteSelectedButton
                    } else {
                        displayMediaList
                    }
                    
                    questionAnswersSection
                }
                .padding()
            }
        }
        .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom).edgesIgnoringSafeArea(.all))
        .navigationBarTitle("", displayMode: .inline)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedMedia: $newMedia)
                .onDisappear(perform: saveMedia)
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
    
    // MARK: - Components

    private var backButton: some View {
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
    }

    private var titleText: some View {
        Text("Profile")
            .foregroundColor(.white)
            .font(.custom("AvenirNext-Bold", size: 20))
    }

    private var editButton: some View {
        Group {
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
        }
    }

    private var settingsButton: some View {
        Button(action: {
            showingSettings.toggle()
        }) {
            Image(systemName: "gearshape")
                .foregroundColor(.white)
                .imageScale(.medium)
        }
    }

    // View to display images/videos in non-edit mode
    private var displayMediaList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 15) {
                Spacer() // Add a spacer to push content towards the center
                ForEach(additionalMedia) { media in
                    if let image = media.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 2))
                            .shadow(radius: 5)
                    } else if let videoURL = media.videoURL {
                        VideoPlayer(player: AVPlayer(url: videoURL))
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 2))
                            .shadow(radius: 5)
                    }
                }
                Spacer() // Add another spacer to center the content
            }
            .padding(.horizontal)
        }
    }

    private var editableMediaList: some View {
        VStack(alignment: .leading, spacing: 15) {
            ForEach(additionalMedia.indices, id: \.self) { index in
                let media = additionalMedia[index]
                HStack {
                    if let image = media.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 2))
                            .shadow(radius: 5)
                    } else if let videoURL = media.videoURL {
                        VideoPlayer(player: AVPlayer(url: videoURL))
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 2))
                            .shadow(radius: 5)
                    }

                    Spacer()

                    // Delete Button for each image/video
                    Button(action: {
                        deleteMedia(at: index)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .padding(4)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }
                    .padding(.trailing, 10)
                }
                .padding(.vertical, 5)
            }
        }
        .padding(.horizontal)
    }

    private var addMediaButton: some View {
        Button(action: {
            self.showingImagePicker = true
        }) {
            Text("Add Images/Videos")
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(8)
        }
        .disabled(additionalMedia.count >= maxMediaCount)
    }

    private var deleteSelectedButton: some View {
        Group {
            if !selectedImages.isEmpty {
                Button(action: {
                    deleteSelectedMedia()
                }) {
                    Text("Delete Selected Media")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(8)
                }
                .padding(.top, 10)
            }
        }
    }

    private var questionAnswersSection: some View {
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
    }
    
    // MARK: - Functions

    private func initializeEditValues() {
        additionalMedia = viewModel.user.additionalImages.compactMap { url -> MediaItem? in
            if url.lowercased().hasSuffix(".jpg") || url.lowercased().hasSuffix(".jpeg") || url.lowercased().hasSuffix(".png") {
                return MediaItem(image: UIImage(contentsOfFile: url))
            } else if url.lowercased().hasSuffix(".mp4") || url.lowercased().hasSuffix(".mov") {
                return MediaItem(videoURL: URL(string: url))
            } else {
                return nil
            }
        }.filter { $0.image != nil || $0.videoURL != nil }
        updatedAnswers = viewModel.user.answers
        selectedImages.removeAll()
        currentIndex = 0 // Reset to the first media
    }

    private func saveProfile() {
        // Upload the media files one by one and update the profile
        saveMedia()
        self.isEditing.toggle()
    }

    private func saveMedia() {
        guard !newMedia.isEmpty else { return }
        
        uploadNewMedia { urls in
            self.additionalMedia.append(contentsOf: urls.map {
                if $0.lowercased().hasSuffix(".jpg") || $0.lowercased().hasSuffix(".jpeg") || $0.lowercased().hasSuffix(".png") {
                    return MediaItem(image: UIImage(contentsOfFile: $0))
                } else {
                    return MediaItem(videoURL: URL(string: $0))
                }
            })
            
            // Update the profile with the newly added media
            self.viewModel.updateUserProfile(
                newAge: self.viewModel.user.age,
                newRank: self.viewModel.user.rank,
                newServer: self.viewModel.user.server,
                additionalImages: self.additionalMedia.compactMap { $0.image != nil ? $0.image!.description : $0.videoURL!.absoluteString },
                updatedAnswers: self.updatedAnswers
            )
            
            // Reset newMedia for next upload
            self.newMedia.removeAll()
        }
    }

    // Function to delete a single image/video at a given index
    private func deleteMedia(at index: Int) {
        let media = additionalMedia[index]
        additionalMedia.remove(at: index)
        // Adjust current index if necessary
        if currentIndex >= additionalMedia.count {
            currentIndex = max(0, additionalMedia.count - 1)
        }
        
        // Update the view model with the changes
        self.viewModel.updateUserProfile(
            newAge: self.viewModel.user.age,
            newRank: self.viewModel.user.rank,
            newServer: self.viewModel.user.server,
            additionalImages: self.additionalMedia.compactMap { $0.image != nil ? $0.image!.description : $0.videoURL!.absoluteString },
            updatedAnswers: self.updatedAnswers
        )
        
        // Proceed to delete the media from Firebase in the background
        if let image = media.image {
            deleteImageFromStorageAndFirestore(url: image.description)
        } else if let videoURL = media.videoURL {
            deleteImageFromStorageAndFirestore(url: videoURL.absoluteString)
        }
    }

    private func deleteSelectedMedia() {
        let indexesToDelete = Array(selectedImages).sorted(by: >)
        let mediaToDelete = indexesToDelete.map { additionalMedia[$0] }
        
        // Remove media from UI immediately
        for index in indexesToDelete {
            additionalMedia.remove(at: index)
        }
        
        selectedImages.removeAll() // Clear selection
        
        // Adjust current index if necessary
        if currentIndex >= additionalMedia.count {
            currentIndex = max(0, additionalMedia.count - 1)
        }
        
        // Update the view model with the changes
        self.viewModel.updateUserProfile(
            newAge: self.viewModel.user.age,
            newRank: self.viewModel.user.rank,
            newServer: self.viewModel.user.server,
            additionalImages: self.additionalMedia.compactMap { $0.image != nil ? $0.image!.description : $0.videoURL!.absoluteString },
            updatedAnswers: self.updatedAnswers
        )
        
        // Proceed to delete media from Firebase
        for media in mediaToDelete {
            if let image = media.image {
                deleteImageFromStorageAndFirestore(url: image.description)
            } else if let videoURL = media.videoURL {
                deleteImageFromStorageAndFirestore(url: videoURL.absoluteString)
            }
        }
    }

    private func deleteImageFromStorageAndFirestore(url: String) {
        let storageRef = Storage.storage().reference(forURL: url)
        storageRef.delete { error in
            if let error = error {
                print("Error deleting image from storage: \(error.localizedDescription)")
            } else {
                print("Image deleted from storage")
                removeImageURLFromFirestore(url: url)
            }
        }
    }

    private func removeImageURLFromFirestore(url: String) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(viewModel.user.id ?? "")
        userRef.updateData([
            "additionalImages": FieldValue.arrayRemove([url])
        ]) { error in
            if let error = error {
                print("Error removing media URL from Firestore: \(error.localizedDescription)")
            } else {
                print("Successfully removed media URL from Firestore")
            }
        }
    }

    private func uploadNewMedia(completion: @escaping ([String]) -> Void) {
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
                
                storageRef.putData(imageData, metadata: metadata) { _, error in
                    if let error = error {
                        print("Error uploading image: \(error.localizedDescription)")
                        dispatchGroup.leave()
                        return
                    }
                    storageRef.downloadURL { url, error in
                        if let downloadURL = url {
                            uploadedURLs.append(downloadURL.absoluteString)
                        }
                        dispatchGroup.leave()
                    }
                }
            } else if let videoURL = media.videoURL {
                let fileName = UUID().uuidString + ".mp4"
                let storageRef = Storage.storage().reference().child("media/\(viewModel.user.id!)/\(fileName)")
                storageRef.putFile(from: videoURL, metadata: nil) { _, error in
                    if let error = error {
                        print("Error uploading video: \(error.localizedDescription)")
                        dispatchGroup.leave()
                        return
                    }
                    storageRef.downloadURL { url, error in
                        if let downloadURL = url {
                            uploadedURLs.append(downloadURL.absoluteString)
                        }
                        dispatchGroup.leave()
                    }
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            saveImageURLsToFirestore(uploadedURLs)
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
                print("Error saving media URLs to Firestore: \(error.localizedDescription)")
            } else {
                print("Successfully saved media URLs to Firestore")
            }
        }
    }

    private func toggleSelection(for index: Int) {
        if selectedImages.contains(index) {
            selectedImages.remove(index)
        } else {
            selectedImages.insert(index)
        }
    }
}
