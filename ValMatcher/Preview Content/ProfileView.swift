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


struct ProfileView: View {
    @ObservedObject var viewModel: UserProfileViewModel
    @Binding var isSignedIn: Bool
    @Environment(\.presentationMode) var presentationMode
    @State private var isEditing = false
    @State private var showingImagePicker = false
    @State private var newMedia: [MediaItem] = []
    @State private var selectedMediaItem: MediaItem?
    @State private var additionalMedia: [MediaItem] = []
    @State private var updatedAnswers: [String: String] = [:]
    @State private var showingSettings = false
    @State private var isShowingLoginView = false
    @State private var selectedMediaIndices: Set<Int> = []
    @State private var uploadProgress: Double = 0.0
    @State private var isUploading: Bool = false
    @State private var uploadMessage: String = ""

    let maxMediaCount = 4
    let maxVideoDuration: Double = 60.0

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
        .overlay(progressOverlay)
        .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom).edgesIgnoringSafeArea(.all))
        .navigationBarTitle("", displayMode: .inline)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedMediaItem: $selectedMediaItem)
                .onDisappear {
                    if let selectedItem = selectedMediaItem {
                        newMedia.append(selectedItem)
                    }
                    saveMedia()
                }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(user: $viewModel.user, isSignedIn: $isSignedIn, isShowingLoginView: $isShowingLoginView)
        }
        .fullScreenCover(isPresented: $isShowingLoginView) {
            LoginView(isSignedIn: $isSignedIn, currentUser: .constant(nil), isShowingLoginView: $isShowingLoginView)
        }
        .onAppear {
            fetchMediaFromFirestore() // Fetch media from Firestore on view load
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
                Spacer()
                ForEach(additionalMedia) { media in
                    if media.type == .image {
                        KFImage(media.url)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(radius: 5)
                    } else if media.type == .video {
                        VideoPlayerView(url: media.url)
                            .frame(width: UIScreen.main.bounds.width * 0.9)  // Adjust width to fit the screen
                            .aspectRatio(contentMode: .fit)  // Ensures the video maintains its aspect ratio
                            .clipped()  // Clips any overflow
                    }
                }
                Spacer()
            }
            .padding(.horizontal)
        }
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
                        VideoPlayer(player: AVPlayer(url: media.url))
                            .frame(width: 100, height: 100)
                            .aspectRatio(contentMode: .fill)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 2))
                            .shadow(radius: 5)
                            .onAppear {
                                AVPlayer(url: media.url).isMuted = false
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
        additionalMedia = viewModel.user.mediaItems
        updatedAnswers = viewModel.user.answers
        selectedMediaIndices.removeAll()
    }

    private func saveProfile() {
        saveMedia()
        self.isEditing.toggle()
    }

    private func saveMedia() {
        guard !newMedia.isEmpty else { return }
        
        if let user = Auth.auth().currentUser {
            isUploading = true
            Task {
                do {
                    let mediaItems = try await uploadNewMedia()
                    self.additionalMedia.append(contentsOf: mediaItems)
                    
                    self.viewModel.updateUserProfile(
                        newAge: self.viewModel.user.age,
                        newRank: self.viewModel.user.rank,
                        newServer: self.viewModel.user.server,
                        mediaItems: self.additionalMedia,
                        updatedAnswers: self.updatedAnswers
                    )
                    self.newMedia.removeAll()
                    
                    saveMediaURLsToFirestore(mediaItems)
                } catch {
                    print("Failed to upload media: \(error)")
                }
                self.isUploading = false
            }
        } else {
            print("No authenticated user found")
        }
    }

    
    private func deleteMedia(at index: Int) {
        let mediaItem = additionalMedia[index]
        additionalMedia.remove(at: index)
        
        self.viewModel.updateUserProfile(
            newAge: self.viewModel.user.age,
            newRank: self.viewModel.user.rank,
            newServer: self.viewModel.user.server,
            mediaItems: self.additionalMedia,
            updatedAnswers: self.updatedAnswers
        )
        
        deleteMediaFromStorageAndFirestore(mediaItem: mediaItem)
    }

    private func deleteSelectedMedia() {
        let indicesToDelete = Array(selectedMediaIndices).sorted(by: >)
        let mediaItemsToDelete = indicesToDelete.map { additionalMedia[$0] }
        
        for index in indicesToDelete {
            additionalMedia.remove(at: index)
        }
        
        selectedMediaIndices.removeAll()
        
        self.viewModel.updateUserProfile(
            newAge: self.viewModel.user.age,
            newRank: self.viewModel.user.rank,
            newServer: self.viewModel.user.server,
            mediaItems: self.additionalMedia,
            updatedAnswers: self.updatedAnswers
        )
        
        for mediaItem in mediaItemsToDelete {
            deleteMediaFromStorageAndFirestore(mediaItem: mediaItem)
        }
    }

    private func deleteMediaFromStorageAndFirestore(mediaItem: MediaItem) {
        let storageRef = Storage.storage().reference(forURL: mediaItem.url.absoluteString)
        storageRef.delete { error in
            if let error = error {
                print("Error deleting media from storage: \(error.localizedDescription)")
            } else {
                print("Media deleted from storage")
                removeMediaURLFromFirestore(url: mediaItem.url.absoluteString)
            }
        }
    }

    private func removeMediaURLFromFirestore(url: String) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(viewModel.user.id ?? "")
        userRef.updateData([
            "mediaItems": FieldValue.arrayRemove([url])
        ]) { error in
            if let error = error {
                print("Error removing media URL from Firestore: \(error.localizedDescription)")
            } else {
                print("Successfully removed media URL from Firestore")
            }
        }
    }

    private func uploadNewMedia() async throws -> [MediaItem] {
        var uploadedMedia: [MediaItem] = []
        
        for media in newMedia {
            if media.type == .image, let image = UIImage(contentsOfFile: media.url.path) {
                let url = try await uploadImageToFirebase(image: image)
                uploadedMedia.append(MediaItem(type: .image, url: url))
            } else if media.type == .video {
                let url = try await uploadVideoToFirebase(videoURL: media.url)
                uploadedMedia.append(MediaItem(type: .video, url: url))
            }
        }
        
        return uploadedMedia
    }
    
    private func uploadImageToFirebase(image: UIImage) async throws -> URL {
        let storageRef = Storage.storage().reference().child("media/\(viewModel.user.id!)/\(UUID().uuidString).jpg")
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
        let storageRef = Storage.storage().reference().child("media/\(viewModel.user.id!)/\(UUID().uuidString).mp4")
        
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
                        if let type = itemData["type"], let urlString = itemData["url"], let url = URL(string: urlString) {
                            if let mediaType = MediaType(rawValue: type) {
                                let mediaItem = MediaItem(type: mediaType, url: url)
                                // Ensure no duplicate entries
                                if !fetchedMediaItems.contains(where: { $0.url == mediaItem.url }) {
                                    fetchedMediaItems.append(mediaItem)
                                }
                            }
                        }
                    }
                    self.additionalMedia = fetchedMediaItems
                    self.viewModel.user.mediaItems = fetchedMediaItems // Update the view model's user profile
                }
            }
        }
    }
}
