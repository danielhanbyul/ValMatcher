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
import Kingfisher

// Identifiable wrapper for URL
struct IdentifiableURL: Identifiable {
    let id = UUID()  // Generate a unique ID
    let url: URL
}

struct ProfileView: View {
    @ObservedObject var viewModel: UserProfileViewModel
    @Binding var isSignedIn: Bool
    @Environment(\.presentationMode) var presentationMode
    @State private var isEditing = false
    @State private var showingImagePicker = false
    @State private var newMedia: [MediaItem] = [] // Temporarily store media before upload
    @State private var selectedMediaItem: MediaItem?
    @State private var additionalMedia: [MediaItem] = []
    @State private var updatedAnswers: [String: String] = [:]
    @State private var showingSettings = false
    @State private var isShowingLoginView = false
    @State private var selectedMediaIndices: Set<Int> = []
    @State private var uploadProgress: Double = 0.0
    @State private var isUploading: Bool = false
    @State private var uploadMessage: String = ""
    @State private var showConfirmButton: Bool = true // Controls confirm button visibility
    @State private var confirmedMediaCount: Int = 0 // Track the confirmed media count

    // Updated to use IdentifiableURL for full-screen video
    @State private var selectedVideoURL: IdentifiableURL?

    let maxMediaCount = 3 // Limit to 3 media items
    let maxVideoDuration: Double = 60.0

    var body: some View {
        VStack {
            headerView

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    UserCardView(user: viewModel.user)

                    if isEditing {
                        // Show temporarily selected media before upload
                        if !newMedia.isEmpty {
                            Text("Selected Media (Tap to remove):")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            // Show new media to the user before uploading
                            HStack {
                                ForEach(newMedia.indices, id: \.self) { index in
                                    let media = newMedia[index]
                                    mediaThumbnailView(for: media)
                                        .onTapGesture {
                                            newMedia.remove(at: index) // Remove selected media on tap
                                            showConfirmButton = true // Show the confirm button again if media is removed
                                            confirmedMediaCount = additionalMedia.count + newMedia.count
                                        }
                                }
                            }
                        }

                        // Media list and buttons
                        editableMediaList

                        // Show confirm button if less than 3 media items are confirmed
                        if confirmedMediaCount < maxMediaCount {
                            addMediaAndConfirmButtons
                        } else {
                            Text("All 3 media items uploaded.")
                                .font(.custom("AvenirNext-Bold", size: 16))
                                .foregroundColor(.green)
                        }
                        
                        deleteSelectedButton
                    } else {
                        displayMediaList
                    }
                    
                    questionAnswersSection
                }
                .padding()
            }
        }
        .overlay(progressOverlay)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.02, green: 0.18, blue: 0.15),
                    Color(red: 0.21, green: 0.29, blue: 0.40)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
        )
        .navigationBarTitle("", displayMode: .inline)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedMediaItem: $selectedMediaItem)
                .onDisappear {
                    if let selectedItem = selectedMediaItem {
                        // Ensure no duplicates are added to newMedia
                        if !newMedia.contains(where: { $0.url == selectedItem.url }) {
                            newMedia.append(selectedItem)
                        }
                        selectedMediaItem = nil // Clear the selectedMediaItem after adding to prevent duplication
                    }
                }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(user: $viewModel.user, isSignedIn: $isSignedIn, isShowingLoginView: $isShowingLoginView)
        }
        .fullScreenCover(item: $selectedVideoURL) { item in
            FullScreenVideoPlayer(url: item.url) // Fullscreen video playback
        }
        .onAppear {
            fetchMediaFromFirestore() // Fetch media from Firestore on view load
            initializeEditValues()
        }
    }

    // MARK: - Components

    // Media thumbnails for preview
    private func mediaThumbnailView(for media: MediaItem) -> some View {
        VStack {
            if media.type == .image {
                KFImage(media.url)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)  // Fixed size
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if media.type == .video {
                VideoPlayer(player: AVPlayer(url: media.url))
                    .frame(width: 100, height: 100)  // Fixed size
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var addMediaButton: some View {
        Button(action: {
            self.showingImagePicker = true
        }) {
            Label("Select Media", systemImage: "plus.circle.fill")
                .font(.custom("AvenirNext-Bold", size: 18))
                .foregroundColor(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(Color.blue)
                .cornerRadius(8)
                .shadow(radius: 3)
        }
        .disabled(newMedia.count + confirmedMediaCount >= maxMediaCount)
    }

    // Add Confirm button to trigger upload
    private var confirmUploadButton: some View {
        Button(action: {
            saveMedia() // Trigger upload
        }) {
            Text("Confirm Upload")
                .foregroundColor(.white)
                .font(.custom("AvenirNext-Bold", size: 18))
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(newMedia.isEmpty ? Color.gray : Color.green)
                .cornerRadius(8)
                .shadow(radius: 3)
        }
        .disabled(newMedia.isEmpty)
    }

    private var addMediaAndConfirmButtons: some View {
        HStack {
            Spacer()
            Button(action: {
                if additionalMedia.count + newMedia.count < maxMediaCount {
                    showingImagePicker = true
                } else {
                    print("ERROR: Cannot add more than \(maxMediaCount) media items.")
                }
            }) {
                Label("Select Media", systemImage: "plus.circle.fill")
                    .font(.custom("AvenirNext-Bold", size: 18))
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(additionalMedia.count + newMedia.count < maxMediaCount ? Color.blue : Color.gray)
                    .cornerRadius(8)
                    .shadow(radius: 3)
            }
            .disabled(additionalMedia.count + newMedia.count >= maxMediaCount)
            
            Spacer()
            confirmUploadButton
            Spacer()
        }
        .padding(.vertical, 15)
    }


    private var headerView: some View {
        HStack {
            backButton
            Spacer()
            if !isEditing {
                titleText
            }
            Spacer()
            if isEditing {
                saveButton
            } else {
                editButton
                settingsButton
            }
        }
        .padding()
        .background(Color.black)
        .frame(height: 44)
    }

    private var saveButton: some View {
        Button(action: {
            saveProfile()
        }) {
            Text("Save")
                .foregroundColor(.white)
                .font(.custom("AvenirNext-Bold", size: 18))
        }
        .padding(.trailing, 10)
    }

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

    private var progressOverlay: some View {
        Group {
            if isUploading {
                VStack {
                    Spacer()
                    ProgressView(value: uploadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .padding()
                    Text(uploadMessage)
                        .foregroundColor(.white)
                        .padding(.bottom)
                    Spacer()
                }
                .background(Color.black.opacity(0.8))
                .edgesIgnoringSafeArea(.all)
            }
        }
    }

    private var displayMediaList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 15) {
                ForEach(additionalMedia.indices, id: \.self) { index in
                    let media = additionalMedia[index]
                    VStack {
                        if media.type == .image {
                            KFImage(media.url)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .shadow(radius: 5)
                        } else if media.type == .video {
                            ZStack {
                                // Thumbnail for video
                                VideoPlayer(player: AVPlayer(url: media.url))
                                    .frame(width: 100, height: 100)
                                    .aspectRatio(contentMode: .fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .onAppear {
                                        // Debug video URL loading
                                        print("DEBUG: Attempting to play video at URL: \(media.url)")
                                        let player = AVPlayer(url: media.url)
                                        player.play()
                                    }

                                Button(action: {
                                    selectedVideoURL = IdentifiableURL(url: media.url)
                                }) {
                                    Image(systemName: "play.circle.fill")
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.5))
                                        .clipShape(Circle())
                                }
                                .position(x: 50, y: 50)
                            }
                            .cornerRadius(10)
                            .shadow(radius: 5)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func debugVideoPlayback(url: URL) {
        print("DEBUG: Attempting playback of video at URL: \(url.absoluteString)")
        let asset = AVAsset(url: url)
        if asset.tracks.isEmpty {
            print("ERROR: No playable tracks found in video asset. Check file encoding.")
        } else {
            print("DEBUG: Video tracks loaded successfully. Asset is playable.")
        }
    }
    
    private func debugVideoURLAccessibility(url: URL) {
        print("DEBUG: Checking video URL accessibility - \(url.absoluteString)")
        
        let asset = AVAsset(url: url)
        if asset.tracks.isEmpty {
            print("ERROR: No tracks found in video asset. The video may be corrupted or in an unsupported format.")
        } else {
            print("DEBUG: Video asset loaded successfully with \(asset.tracks.count) track(s).")
        }
        
        URLSession.shared.dataTask(with: url) { _, response, error in
            if let error = error {
                print("ERROR: Unable to access video URL: \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("ERROR: Received non-200 HTTP response: \(httpResponse.statusCode)")
            } else {
                print("DEBUG: Video URL is accessible.")
            }
        }.resume()
    }



    
    


    private var editableMediaList: some View {
        VStack(alignment: .leading, spacing: 15) {
            ForEach(additionalMedia.indices, id: \.self) { index in
                let media = additionalMedia[index]
                HStack {
                    if media.type == .image {
                        KFImage(media.url)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 2))
                            .shadow(radius: 5)
                    } else if media.type == .video {
                        ZStack {
                            VideoPlayer(player: AVPlayer(url: media.url))
                                .frame(width: 100, height: 100)
                                .aspectRatio(contentMode: .fill)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 2))
                                .shadow(radius: 5)
                            
                            Button(action: {
                                selectedVideoURL = IdentifiableURL(url: media.url)
                            }) {
                                Image(systemName: "play.circle")
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Circle())
                            }
                            .position(x: 50, y: 50)
                        }
                    }

                    Spacer()

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
            .onMove { indices, newOffset in
                additionalMedia.move(fromOffsets: indices, toOffset: newOffset)
                updateMediaOrderInFirestore() // Ensure the updated order is saved in Firestore
            }
        }
        .padding(.horizontal)
        .environment(\.editMode, .constant(.active)) // Enable reordering
    }

    
    private func updateMediaOrderInFirestore() {
        guard let userID = viewModel.user.id else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userID)

        let mediaURLs = additionalMedia.map { ["type": $0.type.rawValue, "url": $0.url.absoluteString] }
        userRef.updateData(["mediaItems": mediaURLs]) { error in
            if let error = error {
                print("Error updating media order in Firestore: \(error.localizedDescription)")
            } else {
                print("Successfully updated media order in Firestore.")
            }
        }
    }
    
    




    private var deleteSelectedButton: some View {
        Group {
            if !selectedMediaIndices.isEmpty {
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
        additionalMedia = viewModel.user.mediaItems ?? []
        updatedAnswers = viewModel.user.answers
        selectedMediaIndices.removeAll()
        confirmedMediaCount = additionalMedia.count
    }

    private func saveProfile() {
        guard let userID = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userID)

        // Prepare updated user data
        var updatedData: [String: Any] = [
            "name": viewModel.user.name,
            "age": viewModel.user.age,
            "mediaItems": viewModel.user.mediaItems?.map {
                ["type": $0.type.rawValue, "url": $0.url.absoluteString]
            } ?? [],
            "profileUpdated": true
        ]

        // Update Firestore
        userRef.updateData(updatedData) { error in
            if let error = error {
                print("Error updating profile: \(error.localizedDescription)")
            } else {
                print("Profile updated successfully.")

                // Reset profileUpdated flag in Firestore
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    userRef.updateData(["profileUpdated": false]) { resetError in
                        if let resetError = resetError {
                            print("Error resetting profileUpdated: \(resetError.localizedDescription)")
                        } else {
                            print("profileUpdated reset to false.")
                        }
                    }
                }

                // Exit edit mode and navigate back to ProfileView
                DispatchQueue.main.async {
                    self.isEditing = false
                    self.presentationMode.wrappedValue.dismiss() // Correct usage
                    print("DEBUG: Navigated back to ProfileView")
                }
            }
        }
    }




    private func saveAnswersToFirestore() {
        guard let userID = viewModel.user.id else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userID)

        // PARTIAL UPDATE for answers
        userRef.updateData([
            "answers": updatedAnswers
        ]) { error in
            if let error = error {
                print("Error saving answers: \(error.localizedDescription)")
            } else {
                print("Answers successfully updated in Firestore.")
                viewModel.user.answers = updatedAnswers
            }
        }
    }
    
    private func saveMedia() {
        guard !newMedia.isEmpty else { return }

        if let user = Auth.auth().currentUser {
            isUploading = true
            Task {
                do {
                    // Upload new media and append to additionalMedia
                    let mediaItems = try await uploadNewMedia()
                    
                    // Avoid duplicate entries by checking for existing URLs
                    let uniqueMediaItems = mediaItems.filter { newItem in
                        !self.additionalMedia.contains(where: { $0.url == newItem.url })
                    }

                    self.additionalMedia.append(contentsOf: uniqueMediaItems) // Append only unique items
                    updateMediaOrderInFirestore() // Save the new order in Firestore

                    // Debug log for added media
                    for mediaItem in uniqueMediaItems {
                        debugVideoPlayback(url: mediaItem.url)
                    }

                    // PARTIAL UPDATE for media in Firestore
                    let userRef = Firestore.firestore().collection("users").document(user.uid)
                    let mediaDicts = self.additionalMedia.map { [
                        "type": $0.type.rawValue,
                        "url": $0.url.absoluteString
                    ]}

                    try await userRef.setData(["mediaItems": mediaDicts], merge: true)

                    // Update local state
                    self.viewModel.user.mediaItems = self.additionalMedia
                    self.newMedia.removeAll() // Clear temporary new media

                    confirmedMediaCount = additionalMedia.count
                } catch {
                    print("Failed to upload media: \(error)")
                }
                self.isUploading = false
            }
        } else {
            print("No authenticated user found")
        }
    }


    



    private func addMediaItem(type: MediaType, url: URL) {
        guard let userId = viewModel.user.id else { return }

        // Update local user in the viewModel
        viewModel.user.mediaItems = (viewModel.user.mediaItems ?? []) + [MediaItem(type: type, url: url)]

        // Update Firestore with the new media item and set `profileUpdated` to true
        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "mediaItems": viewModel.user.mediaItems?.map { ["type": $0.type.rawValue, "url": $0.url.absoluteString] } ?? [],
            "profileUpdated": true
        ]) { error in
            if let error = error {
                print("Error updating user profile with media item: \(error.localizedDescription)")
            } else {
                print("DEBUG: Media item added and profileUpdated set to true for user \(userId).")
            }
        }

        // Reset `profileUpdated` to false after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            db.collection("users").document(userId).updateData([
                "profileUpdated": false
            ]) { error in
                if let error = error {
                    print("Error resetting profileUpdated flag: \(error.localizedDescription)")
                } else {
                    print("DEBUG: profileUpdated reset to false for user \(userId).")
                }
            }
        }
    }



    private func deleteMedia(at index: Int) {
        guard index >= 0 && index < additionalMedia.count else {
            print("Error: Index out of bounds")
            return
        }

        let mediaItem = additionalMedia[index]
        print("DEBUG: Deleting media item: \(mediaItem.url.absoluteString), type: \(mediaItem.type.rawValue)")

        // Remove from Firebase Storage
        let storageRef = Storage.storage().reference(forURL: mediaItem.url.absoluteString)
        storageRef.delete { error in
            if let error = error {
                print("Error deleting media from Firebase Storage: \(error.localizedDescription)")
            } else {
                print("DEBUG: Media successfully deleted from Firebase Storage")
                self.removeMediaURLFromFirestore(mediaItem: mediaItem)
            }
        }

        // Remove from local state
        additionalMedia.remove(at: index)
        confirmedMediaCount = additionalMedia.count + newMedia.count
    }


    private func removeMediaURLFromFirestore(mediaItem: MediaItem) {
        guard let userID = viewModel.user.id else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userID)

        let mediaDict = ["type": mediaItem.type.rawValue, "url": mediaItem.url.absoluteString]
        userRef.updateData([
            "mediaItems": FieldValue.arrayRemove([mediaDict])
        ]) { error in
            if let error = error {
                print("Error removing media URL from Firestore: \(error.localizedDescription)")
            } else {
                print("DEBUG: Successfully removed media URL from Firestore")
                // Synchronize local state with Firestore
                self.additionalMedia.removeAll { $0.url == mediaItem.url }
                self.viewModel.user.mediaItems = self.additionalMedia
            }
        }
    }



    private func deleteSelectedMedia() {
        let indicesToDelete = Array(selectedMediaIndices).sorted(by: >) // Sort to avoid index errors
        let mediaItemsToDelete = indicesToDelete.map { additionalMedia[$0] }

        // Remove from local state
        for index in indicesToDelete {
            additionalMedia.remove(at: index)
        }
        selectedMediaIndices.removeAll()

        // Remove each media item from Firebase
        for mediaItem in mediaItemsToDelete {
            deleteMediaFromStorageAndFirestore(mediaItem: mediaItem)
        }

        confirmedMediaCount = additionalMedia.count + newMedia.count
    }


    

    private func deleteMediaFromStorageAndFirestore(mediaItem: MediaItem) {
        print("DEBUG: Deleting media item from Storage and Firestore: \(mediaItem.url.absoluteString)")
        
        // Delete from Firebase Storage
        let storageRef = Storage.storage().reference(forURL: mediaItem.url.absoluteString)
        storageRef.delete { error in
            if let error = error {
                print("Error deleting media from Firebase Storage: \(error.localizedDescription)")
            } else {
                print("DEBUG: Media successfully deleted from Firebase Storage")
                self.removeMediaURLFromFirestore(mediaItem: mediaItem)
            }
        }
    }


    private func removeMediaURLFromFirestore(url: String, type: MediaType) {
        guard let userID = viewModel.user.id else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userID)

        // Remove the specific media URL and type
        userRef.updateData([
            "mediaItems": FieldValue.arrayRemove([["type": type.rawValue, "url": url]])
        ]) { error in
            if let error = error {
                print("Error removing media URL from Firestore: \(error.localizedDescription)")
            } else {
                print("Successfully removed media URL from Firestore")
                // Update local state
                self.additionalMedia.removeAll { $0.url.absoluteString == url }
                self.viewModel.user.mediaItems = self.additionalMedia
            }
        }
    }


    


    

    private func uploadNewMedia() async throws -> [MediaItem] {
        var uploadedMedia: [MediaItem] = []

        for media in newMedia {
            if media.type == .image {
                guard let image = UIImage(contentsOfFile: media.url.path) else {
                    print("ERROR: Invalid image file.")
                    continue
                }
                let url = try await uploadImageToFirebase(image: image)
                uploadedMedia.append(MediaItem(type: .image, url: url))
            } else if media.type == .video {
                let asset = AVAsset(url: media.url)
                if asset.tracks.isEmpty {
                    print("ERROR: Invalid video file. Skipping upload.")
                    continue
                }
                let url = try await uploadVideoToFirebase(videoURL: media.url)
                uploadedMedia.append(MediaItem(type: .video, url: url))
            } else {
                print("ERROR: Unsupported media type.")
            }
        }
        return uploadedMedia
    }

    private func debugMediaType(for url: URL) {
        let asset = AVAsset(url: url)
        if asset.tracks.isEmpty {
            print("ERROR: No playable tracks found. File may not be a valid video.")
        } else {
            print("DEBUG: Media contains \(asset.tracks.count) playable track(s).")
        }
    }

    
    private func uploadImageToFirebase(image: UIImage) async throws -> URL {
        guard let userId = viewModel.user.id else {
            throw UploadError.fileNotFound
        }
        let storageRef = Storage.storage().reference().child("media/\(userId)/\(UUID().uuidString).jpg")
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw UploadError.compressionFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let uploadTask = storageRef.putData(imageData, metadata: nil) { metadata, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                storageRef.downloadURL { url, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let url = url else {
                        continuation.resume(throwing: UploadError.urlNil)
                        return
                    }
                    continuation.resume(returning: url)
                }
            }
            
            uploadTask.observe(.progress) { snapshot in
                let fractionCompleted = Double(snapshot.progress!.fractionCompleted)
                self.uploadProgress = fractionCompleted
                self.uploadMessage = "Uploading image \(Int(self.uploadProgress * 100))%"
            }
        }
    }

    private func uploadVideoToFirebase(videoURL: URL) async throws -> URL {
        guard let userId = viewModel.user.id else {
            throw UploadError.fileNotFound
        }
        let storageRef = Storage.storage().reference().child("media/\(userId)/\(UUID().uuidString).mp4")
        
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            throw UploadError.fileNotFound
        }

        let videoData = try Data(contentsOf: videoURL)

        return try await withCheckedThrowingContinuation { continuation in
            let uploadTask = storageRef.putData(videoData, metadata: nil) { metadata, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                storageRef.downloadURL { url, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let url = url else {
                        continuation.resume(throwing: UploadError.urlNil)
                        return
                    }
                    continuation.resume(returning: url)
                }
            }
            
            uploadTask.observe(.progress) { snapshot in
                let fractionCompleted = Double(snapshot.progress!.fractionCompleted)
                self.uploadProgress = fractionCompleted
                self.uploadMessage = "Uploading video \(Int(self.uploadProgress * 100))%"
            }
        }
    }

    enum UploadError: Error {
        case compressionFailed
        case urlNil
        case fileNotFound
    }
    
    private func getVideoURL(from asset: PHAsset, completion: @escaping (URL?) -> Void) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            guard let asset = avAsset as? AVURLAsset else {
                completion(nil)
                return
            }
            completion(asset.url)
        }
    }
    
    private func generateThumbnail(for url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print("DEBUG: Failed to generate thumbnail: \(error.localizedDescription)")
            return nil
        }
    }


    private func copyVideoToDocumentsDirectory(url: URL) -> URL? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsURL.appendingPathComponent(url.lastPathComponent)
        
        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: url, to: destinationURL)
            return destinationURL
        } catch {
            return nil
        }
    }

    private func saveMediaURLsToFirestore(_ mediaItems: [MediaItem]) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(viewModel.user.id ?? "")
        let mediaURLs = mediaItems.map { ["type": $0.type.rawValue, "url": $0.url.absoluteString] }
        
        userRef.updateData([
            "mediaItems": FieldValue.arrayUnion(mediaURLs)
        ]) { error in
            if let error = error {
                print("Error saving media URLs to Firestore: \(error.localizedDescription)")
            }
        }
    }

    private func fetchMediaFromFirestore() {
        guard let userID = viewModel.user.id else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userID)

        userRef.getDocument { document, error in
            if let error = error {
                print("Error fetching media from Firestore: \(error.localizedDescription)")
                return
            }

            if let document = document, document.exists {
                if let mediaItemsData = document.data()?["mediaItems"] as? [[String: String]] {
                    var fetchedMediaItems: [MediaItem] = []
                    for itemData in mediaItemsData {
                        if let type = itemData["type"],
                           let urlString = itemData["url"],
                           let url = URL(string: urlString),
                           url.isPublicURL {
                            if let mediaType = MediaType(rawValue: type) {
                                let mediaItem = MediaItem(type: mediaType, url: url)
                                fetchedMediaItems.append(mediaItem)
                            }
                        }
                    }
                    self.additionalMedia = fetchedMediaItems
                    self.viewModel.user.mediaItems = fetchedMediaItems // Update view model
                }
            }
        }
    }


}

struct FullScreenVideoPlayer: View {
    let url: URL
    @Environment(\.presentationMode) var presentationMode

    @State private var player: AVPlayer?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            if isLoading {
                ProgressView("Loading video...")
                    .foregroundColor(.white)
                    .onAppear {
                        loadVideo()
                    }
            } else if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.play()
                        print("DEBUG: Video playback started.")
                    }
                    .onDisappear {
                        player.pause()
                        print("DEBUG: Video playback paused.")
                    }
            } else {
                Text("Unable to load video")
                    .foregroundColor(.red)
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }

    private func loadVideo() {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVAsset(url: url)
            let playerItem = AVPlayerItem(asset: asset)

            DispatchQueue.main.async {
                self.player = AVPlayer(playerItem: playerItem)
                self.isLoading = false
            }
        }
    }
}


private func debugVideoURLAccessibility(url: URL) {
    print("DEBUG: Checking video URL accessibility - \(url.absoluteString)")
    
    let asset = AVAsset(url: url)
    if asset.tracks.isEmpty {
        print("ERROR: No tracks found in video asset. The video may be corrupted or in an unsupported format.")
    } else {
        print("DEBUG: Video asset loaded successfully with \(asset.tracks.count) track(s).")
    }
    
    URLSession.shared.dataTask(with: url) { _, response, error in
        if let error = error {
            print("ERROR: Unable to access video URL: \(error.localizedDescription)")
        } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            print("ERROR: Received non-200 HTTP response: \(httpResponse.statusCode)")
        } else {
            print("DEBUG: Video URL is accessible.")
        }
    }.resume()
}


private func debugVideoURL(url: URL) {
    print("DEBUG: Checking video URL - \(url.absoluteString)")
    let asset = AVAsset(url: url)
    if asset.tracks.isEmpty {
        print("ERROR: No tracks found in video asset. The file may be corrupted or in an unsupported format.")
    } else {
        print("DEBUG: Video tracks loaded successfully.")
    }
}




private func generateVideoThumbnail(url: URL) -> UIImage? {
    let asset = AVAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true

    do {
        let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
        return UIImage(cgImage: cgImage)
    } catch {
        print("DEBUG: Failed to generate thumbnail for video: \(error)")
        return nil
    }
}


private func mediaThumbnailView(for media: MediaItem) -> some View {
    VStack {
        if media.type == .image {
            KFImage(media.url)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else if media.type == .video {
            VideoPlayerView(url: media.url)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}







// Example Usage in a Parent View
struct ParentView: View {
    @State private var selectedVideoURL: IdentifiableURL?

    var body: some View {
        Button("Play Video") {
            selectedVideoURL = IdentifiableURL(url: URL(string: "https://example.com/video.mp4")!)
        }
        .fullScreenCover(item: $selectedVideoURL) { item in
            FullScreenVideoPlayer(url: item.url) // Pass the URL to FullScreenVideoPlayer
        }
    }
}
