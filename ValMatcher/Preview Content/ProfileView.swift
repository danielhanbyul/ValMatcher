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
import PhotosUI

struct ProfileView: View {
    @ObservedObject var viewModel: UserProfileViewModel
    @Binding var isSignedIn: Bool
    @Environment(\.presentationMode) var presentationMode
    @State private var isEditing = false
    @State private var showingImagePicker = false
    @State private var newMedia: [MediaItem] = []
    @State private var additionalImages: [String] = []
    @State private var updatedAnswers: [String: String] = [:]
    @State private var showingSettings = false
    @State private var isShowingLoginView = false
    @State private var selectedImages: Set<Int> = []
    @State private var currentIndex: Int = 0 // To track the current image being displayed
    @State private var videoURL: URL? = nil // Updated to URL? type
    @State private var showingVideoPicker = false // To trigger video picker

    let maxImageCount = 3 // Maximum number of images allowed

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
                        editableImageList
                        addImageButton
                        addVideoButton // Add video button
                        deleteSelectedButton
                    } else {
                        displayImageList
                        displayVideo // Display video if available
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
        .sheet(isPresented: $showingVideoPicker) {
            VideoPicker(selectedVideoURL: $videoURL)
                .onDisappear(perform: saveVideo)
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

    // View to display images in non-edit mode
    private var displayImageList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 15) {
                Spacer() // Add a spacer to push content towards the center
                ForEach(additionalImages, id: \.self) { urlString in
                    if let url = URL(string: urlString), !url.absoluteString.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                            case .success(let image):
                                image.resizable()
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
                    }
                }
                Spacer() // Add another spacer to center the content
            }
            .padding(.horizontal)
        }
    }
    
    private var displayVideo: some View {
        Group {
            if let url = videoURL {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(height: 200)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 5)
                    .padding()
            }
        }
    }

    private var editableImageList: some View {
        VStack(alignment: .leading, spacing: 15) {
            ForEach(additionalImages.indices, id: \.self) { index in
                let urlString = additionalImages[index]
                if let url = URL(string: urlString), !url.absoluteString.isEmpty {
                    HStack {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                            case .success(let image):
                                image.resizable()
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

                        Spacer()

                        // Delete Button for each image
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
                        .padding(.trailing, 10)
                    }
                    .padding(.vertical, 5)
                }
            }
        }
        .padding(.horizontal)
    }

    private var addImageButton: some View {
        Button(action: {
            self.showingImagePicker = true
        }) {
            Text("Add Images/Videos")
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(8)
        }
        .disabled(additionalImages.count >= maxImageCount)
    }

    private var addVideoButton: some View {
        Button(action: {
            self.showingVideoPicker = true
        }) {
            Text("Add Video")
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(8)
        }
        .disabled(videoURL != nil) // Only allow one video
    }

    private var deleteSelectedButton: some View {
        Group {
            if !selectedImages.isEmpty {
                Button(action: {
                    deleteSelectedImages()
                }) {
                    Text("Delete Selected Images")
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
        additionalImages = viewModel.user.additionalImages.compactMap { $0 }.filter { !$0.isEmpty }
        videoURL = viewModel.user.videoURL.flatMap { URL(string: $0) }
        updatedAnswers = viewModel.user.answers
        selectedImages.removeAll()
        currentIndex = 0 // Reset to the first image
    }

    private func saveProfile() {
        // Upload the media files one by one and update the profile
        saveMedia()
        self.isEditing.toggle()
    }

    private func saveMedia() {
        guard !newMedia.isEmpty else { return }
        
        uploadNewMedia { urls in
            self.additionalImages.append(contentsOf: urls)
            
            // Update the profile with the newly added images
            self.viewModel.updateUserProfile(
                newAge: self.viewModel.user.age,
                newRank: self.viewModel.user.rank,
                newServer: self.viewModel.user.server,
                additionalImages: self.additionalImages.map { $0 },
                updatedAnswers: self.updatedAnswers
                // Removed videoURL here
            )
            
            // Reset newMedia for next upload
            self.newMedia.removeAll()
        }
    }

    private func saveVideo() {
        guard let selectedVideoURL = videoURL else { return }
        
        uploadVideo(selectedVideoURL) { url in
            self.videoURL = url
            
            // Update the profile with the newly added video
            self.viewModel.updateUserProfile(
                newAge: self.viewModel.user.age,
                newRank: self.viewModel.user.rank,
                newServer: self.viewModel.user.server,
                additionalImages: self.additionalImages.map { $0 },
                updatedAnswers: self.updatedAnswers
                // Removed videoURL here
            )
        }
    }

    // Function to delete a single image at a given index
    private func deleteImage(at index: Int) {
        let urlString = additionalImages[index]
        
        // Remove the image from the UI immediately
        additionalImages.remove(at: index)
        
        // Adjust current index if necessary
        if currentIndex >= additionalImages.count {
            currentIndex = max(0, additionalImages.count - 1)
        }
        
        // Update the view model with the changes
        self.viewModel.updateUserProfile(
            newAge: self.viewModel.user.age,
            newRank: self.viewModel.user.rank,
            newServer: self.viewModel.user.server,
            additionalImages: self.additionalImages.map { $0 },
            updatedAnswers: self.updatedAnswers
            // Removed videoURL here
        )
        
        // Proceed to delete the image from Firebase in the background
        deleteImageFromStorageAndFirestore(url: urlString)
    }

    private func deleteSelectedImages() {
        let indexesToDelete = Array(selectedImages).sorted(by: >)
        let urlsToDelete = indexesToDelete.map { additionalImages[$0] }
        
        // Remove images from UI immediately
        for index in indexesToDelete {
            additionalImages.remove(at: index)
        }
        
        selectedImages.removeAll() // Clear selection
        
        // Adjust current index if necessary
        if currentIndex >= additionalImages.count {
            currentIndex = max(0, additionalImages.count - 1)
        }
        
        // Update the view model with the changes
        self.viewModel.updateUserProfile(
            newAge: self.viewModel.user.age,
            newRank: self.viewModel.user.rank,
            newServer: self.viewModel.user.server,
            additionalImages: self.additionalImages.map { $0 },
            updatedAnswers: self.updatedAnswers
            // Removed videoURL here
        )
        
        // Proceed to delete images from Firebase
        for urlString in urlsToDelete {
            deleteImageFromStorageAndFirestore(url: urlString)
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

    private func deleteVideo() {
        guard let videoURL = videoURL else { return }
        
        deleteImageFromStorageAndFirestore(url: videoURL.absoluteString)
        
        // Remove video URL from the profile
        self.videoURL = nil
        
        // Update the view model with the changes
        self.viewModel.updateUserProfile(
            newAge: self.viewModel.user.age,
            newRank: self.viewModel.user.rank,
            newServer: self.viewModel.user.server,
            additionalImages: self.additionalImages.map { $0 },
            updatedAnswers: self.updatedAnswers
            // Removed videoURL here
        )
    }

    private func removeImageURLFromFirestore(url: String) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(viewModel.user.id ?? "")
        userRef.updateData([
            "additionalImages": FieldValue.arrayRemove([url])
        ]) { error in
            if let error = error {
                print("Error removing image URL from Firestore: \(error.localizedDescription)")
            } else {
                print("Successfully removed image URL from Firestore")
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
            }
        }

        dispatchGroup.notify(queue: .main) {
            saveImageURLsToFirestore(uploadedURLs)
            completion(uploadedURLs)
        }
    }

    private func uploadVideo(_ videoURL: URL, completion: @escaping (URL) -> Void) {
        let fileName = UUID().uuidString + ".mp4"
        let storageRef = Storage.storage().reference().child("media/\(viewModel.user.id!)/\(fileName)")
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        
        storageRef.putFile(from: videoURL, metadata: metadata) { _, error in
            if let error = error {
                print("Error uploading video: \(error.localizedDescription)")
                return
            }
            storageRef.downloadURL { url, error in
                if let downloadURL = url {
                    completion(downloadURL)
                }
            }
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

    private func toggleSelection(for index: Int) {
        if selectedImages.contains(index) {
            selectedImages.remove(index)
        } else {
            selectedImages.insert(index)
        }
    }
}

// MARK: - VideoPicker Implementation

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var selectedVideoURL: URL?

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: VideoPicker

        init(parent: VideoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let result = results.first else { return }

            if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { (url, error) in
                    if let url = url {
                        DispatchQueue.main.async {
                            self.parent.selectedVideoURL = url
                        }
                    }
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
}
