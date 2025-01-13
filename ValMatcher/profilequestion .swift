//
//  profilequestion .swift
//  ValMatcher
//
//  Created by Ryan Kim on 6/6/24.
//

import SwiftUI
import FirebaseFirestore
import Firebase
import FirebaseStorage
import AVFoundation

// ==============================
// MARK: - MediaUploader (NEW)
// ==============================
// This class provides async/await uploads that return
// the final public download URL from Firebase Storage.
enum UploadError: Error {
    case compressionFailed
    case urlNil
    case fileNotFound
}

class MediaUploader {
    /// Uploads a UIImage to Firebase Storage, returns its public HTTPS URL.
    static func uploadImageToFirebase(userId: String, image: UIImage) async throws -> URL {
        let storageRef = Storage.storage().reference().child("media/\(userId)/\(UUID().uuidString).jpg")
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw UploadError.compressionFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let uploadTask = storageRef.putData(imageData, metadata: nil) { _, error in
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

            // Optional: progress observer
            uploadTask.observe(.progress) { snapshot in
                let fractionCompleted = Double(snapshot.progress?.fractionCompleted ?? 0)
                print("Image upload progress: \(fractionCompleted)")
            }
        }
    }

    /// Uploads a local video to Firebase Storage, returns its public HTTPS URL.
    static func uploadVideoToFirebase(userId: String, videoURL: URL) async throws -> URL {
        let storageRef = Storage.storage().reference().child("media/\(userId)/\(UUID().uuidString).mp4")

        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            throw UploadError.fileNotFound
        }

        let videoData = try Data(contentsOf: videoURL)

        return try await withCheckedThrowingContinuation { continuation in
            let uploadTask = storageRef.putData(videoData, metadata: nil) { _, error in
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

            // Optional: progress observer
            uploadTask.observe(.progress) { snapshot in
                let fractionCompleted = Double(snapshot.progress?.fractionCompleted ?? 0)
                print("Video upload progress: \(fractionCompleted)")
            }
        }
    }
}

// ==============================
// MARK: - Global Data
// ==============================

// Define the questions globally
let profileQuestions: [String] = [
    "Who's your favorite agent to play in Valorant?",
    "Do you prefer playing as a Duelist, Initiator, Controller, or Sentinel?",
    "What’s your current rank in Valorant?",
    "Favorite game mode?",
    "What servers do you play on?",
    "What's your favorite weapon skin in Valorant?"
]

// Existing questions remain the same:
struct QuestionsView: View {
    @State private var currentQuestionIndex = 0
    @State private var answer = ""
    @State private var selectedOption: String = ""
    @State private var errorMessage = ""

    // Example questions array
    @State private var questions: [Question] = [
        Question(text: "How old are you?", type: .text),
        Question(text: "Who's your favorite agent to play in Valorant?",
                 type: .multipleChoice(options: ["Jett", "Sage", "Phoenix", "Brimstone", "Viper", "Omen", "Cypher", "Reyna", "Killjoy", "Skye", "Yoru", "Astra", "KAY/O", "Chamber", "Neon", "Fade", "Harbor", "Gekko"])),
        Question(text: "Do you prefer playing as a Duelist, Initiator, Controller, or Sentinel?",
                 type: .multipleChoice(options: ["Duelist", "Initiator", "Controller", "Sentinel"])),
        Question(text: "What’s your current rank in Valorant?", type: .text),
        Question(text: "Favorite game mode?",
                 type: .multipleChoice(options: ["Competitive", "Unrated", "Spike Rush", "Deathmatch"])),
        Question(text: "What servers do you play on?", type: .text),
        Question(text: "What's your favorite weapon skin in Valorant?", type: .text)
    ]

    // Bindings for the user profile and completion state
    @Binding var userProfile: UserProfile
    @Binding var hasAnsweredQuestions: Bool

    // States for media uploads
    @State private var newMedia: [MediaItem] = []
    @State private var showingImagePicker = false
    @State private var selectedMediaItem: MediaItem? = nil
    @State private var mediaErrorMessage = ""
    @State private var isUploadingMedia = false

    // Environment
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            if currentQuestionIndex < questions.count {
                questionAnswerSection
            } else {
                uploadMediaStep
            }
        }
        .padding()
        .navigationBarHidden(true)
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedMediaItem: $selectedMediaItem)
                .onDisappear {
                    handleSelectedMedia()
                }
        }
    }

    // MARK: - Subviews

    private var questionAnswerSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(questions[currentQuestionIndex].text)
                .font(.custom("AvenirNext-Bold", size: 24))
                .padding(.top, 20)

            if case .multipleChoice(let options) = questions[currentQuestionIndex].type {
                Picker("Select an option", selection: $selectedOption) {
                    ForEach(options, id: \.self) { option in
                        Text(option).font(.custom("AvenirNext-Regular", size: 18))
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .padding(.horizontal)
                .onAppear {
                    if selectedOption.isEmpty {
                        selectedOption = options.first ?? ""
                    }
                }
            } else {
                TextField("Your answer", text: $answer)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            Button(action: handleNextQuestion) {
                Text("Next")
                    .foregroundColor(.white)
                    .font(.custom("AvenirNext-Bold", size: 18))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
        }
    }

    private var uploadMediaStep: some View {
        VStack(spacing: 16) {
            Text("Showcase Your Valorant Skills")
                .font(.custom("AvenirNext-Bold", size: 24))
                .multilineTextAlignment(.center)
                .padding(.top, 10)

            Text("Please upload 4-6 pictures or videos showcasing your Valorant skills.")
                .font(.custom("AvenirNext-Regular", size: 16))
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal)

            ScrollView {
                VStack(spacing: 20) {
                    ForEach(newMedia.indices, id: \.self) { index in
                        let media = newMedia[index]
                        HStack(spacing: 10) {
                            mediaThumbnailView(for: media)
                                .frame(width: 100, height: 100)
                                .onTapGesture {
                                    newMedia.remove(at: index)
                                }

                            VStack(alignment: .leading) {
                                Text("Media \(index + 1)")
                                    .font(.custom("AvenirNext-Bold", size: 16))
                                Text(media.type == .image ? "Image" : "Video")
                                    .font(.custom("AvenirNext-Regular", size: 14))
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            Button(action: {
                                newMedia.remove(at: index)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .padding()
                            }
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .gray.opacity(0.3), radius: 5, x: 0, y: 3)
                    }

                    Button {
                        showingImagePicker = true
                    } label: {
                        Label("Add Media", systemImage: "plus.circle.fill")
                            .font(.custom("AvenirNext-Bold", size: 18))
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    .disabled(newMedia.count >= 6)
                }
            }

            if isUploadingMedia {
                ProgressView("Uploading media...")
            }

            if !mediaErrorMessage.isEmpty {
                Text(mediaErrorMessage)
                    .foregroundColor(.red)
            }

            Button(action: finishQuestionsAndSaveProfile) {
                Text("Finish")
                    .foregroundColor(.white)
                    .font(.custom("AvenirNext-Bold", size: 18))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(newMedia.count >= 4 ? Color.green : Color.gray)
                    .cornerRadius(8)
            }
            .disabled(newMedia.count < 4)
            .padding(.horizontal)
        }
    }

    // MARK: - Helper Functions

    private func handleNextQuestion() {
        let currentQ = questions[currentQuestionIndex]

        if !isValidAnswer(for: currentQ) {
            errorMessage = "Please provide a valid answer."
            return
        } else {
            errorMessage = ""
        }

        if case .multipleChoice(_) = currentQ.type {
            questions[currentQuestionIndex].answer = selectedOption
            userProfile.answers[currentQ.text] = selectedOption
            selectedOption = ""
        } else {
            questions[currentQuestionIndex].answer = answer
            userProfile.answers[currentQ.text] = answer
            answer = ""
        }

        currentQuestionIndex += 1
    }

    private func isValidAnswer(for question: Question) -> Bool {
        switch question.type {
        case .text:
            return !answer.isEmpty
        case .multipleChoice:
            return !selectedOption.isEmpty
        }
    }

    private func handleSelectedMedia() {
        if let selectedItem = selectedMediaItem {
            if !newMedia.contains(where: { $0.url == selectedItem.url }) {
                newMedia.append(selectedItem)
                print("DEBUG: Added media item - Type: \(selectedItem.type), URL: \(selectedItem.url)")
                mediaErrorMessage = ""
            }
            selectedMediaItem = nil
        }
    }

    // ================================
    // MARK: - NEW finishQuestionsAndSaveProfile
    // ================================
    // Rewritten to use MediaUploader for final public URLs,
    // matching the logic in ProfileView.
    private func finishQuestionsAndSaveProfile() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("ERROR: No authenticated user found.")
            return
        }

        // Ensure there are at least 4 combined media items
        guard newMedia.count >= 4 else {
            mediaErrorMessage = "You must upload at least 4 media items (images or videos)."
            return
        }

        // If you want a maximum of 6:
        if newMedia.count > 6 {
            mediaErrorMessage = "You cannot upload more than 6 media items!"
            return
        }

        isUploadingMedia = true

        // We'll do an async Task for uploading
        Task {
            var uploadedMedia: [MediaItem] = []

            do {
                // For each media item, get a final public URL via MediaUploader
                for media in newMedia {
                    switch media.type {
                    case .image:
                        guard let image = UIImage(contentsOfFile: media.url.path) else {
                            print("ERROR: Invalid local image file.")
                            continue
                        }
                        let downloadURL = try await MediaUploader.uploadImageToFirebase(userId: uid, image: image)
                        uploadedMedia.append(MediaItem(type: .image, url: downloadURL))

                    case .video:
                        let asset = AVAsset(url: media.url)
                        if asset.tracks.isEmpty {
                            print("ERROR: Invalid local video file. Skipping upload.")
                            continue
                        }
                        let downloadURL = try await MediaUploader.uploadVideoToFirebase(userId: uid, videoURL: media.url)
                        uploadedMedia.append(MediaItem(type: .video, url: downloadURL))
                    }
                }

                // Verify we still got at least 4 successful uploads
                if uploadedMedia.count < 4 {
                    mediaErrorMessage = "Failed to upload at least 4 media items. Try again."
                    isUploadingMedia = false
                    return
                }

                // Save user profile with final public URLs
                userProfile.mediaItems = uploadedMedia
                userProfile.hasAnsweredQuestions = true

                try await saveUserProfileAndMediaAsync() // Use an async version
                hasAnsweredQuestions = true
            } catch {
                print("DEBUG: Error uploading media: \(error.localizedDescription)")
                mediaErrorMessage = "Failed to upload media. Please try again."
            }

            isUploadingMedia = false
        }
    }

    // ================================
    // MARK: - The old uploadMedia function
    // ================================
    // We keep this function so nothing is removed.
    // It's not used now, but remains for reference.
    private func uploadMedia(fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        // Example stub that used to do a custom upload...
        // You can remove or ignore if you want, but we keep it here per your request.
        completion(.failure(NSError(domain: "uploadMedia", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not used anymore"])))
    }

    // ================================
    // MARK: - Saving the user profile
    // ================================

    // The original function remains:
    private func saveUserProfileAndMedia(completion: @escaping () -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()

        do {
            try db.collection("users").document(uid).setData(from: userProfile, merge: true) { err in
                if let err = err {
                    print("Error writing user to Firestore: \(err.localizedDescription)")
                } else {
                    print("Successfully saved updated user profile with mediaItems.")
                    self.hasAnsweredQuestions = true
                    completion()
                }
            }
        } catch {
            print("Error encoding user: \(error.localizedDescription)")
        }
    }

    // A new async version that does the same thing
    private func saveUserProfileAndMediaAsync() async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        try db.collection("users").document(uid).setData(from: userProfile, merge: true)
        print("Successfully saved updated user profile with mediaItems (async).")
    }

    // MARK: - mediaThumbnailView
    private func mediaThumbnailView(for media: MediaItem) -> some View {
        if media.type == .image {
            return AnyView(
                Image(uiImage: UIImage(contentsOfFile: media.url.path) ?? UIImage())
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            )
        } else {
            return AnyView(
                ZStack {
                    Color.black
                    Image(systemName: "play.rectangle.fill")
                        .resizable()
                        .foregroundColor(.white)
                        .frame(width: 40, height: 30)
                }
                .frame(width: 80, height: 80)
            )
        }
    }
}

// ==============================
// MARK: - Minimal SwiftUI Thumbnails for image / video
// ==============================
struct ImageThumbnailView: View {
    let url: URL
    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                Color.red
            @unknown default:
                EmptyView()
            }
        }
    }
}

/// Example video thumbnail (very simplified placeholder)
struct VideoThumbnailView: View {
    let url: URL

    var body: some View {
        if let thumbnail = generateThumbnail(for: url) {
            Image(uiImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Image(systemName: "video")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.gray)
        }
    }

    private func generateThumbnail(for url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print("DEBUG: Failed to generate thumbnail for video: \(error.localizedDescription)")
            return nil
        }
    }
}
