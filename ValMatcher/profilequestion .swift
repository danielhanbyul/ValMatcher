//
//  profilequestion .swift
//  ValMatcher
//
//  Created by Ryan Kim on 6/6/24.
//

import SwiftUI
import FirebaseFirestore
import Firebase

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

            Text("Please upload at least 3 pictures or videos showcasing your Valorant skills.")
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
                    .background(newMedia.count >= 3 ? Color.green : Color.gray)
                    .cornerRadius(8)
            }
            .disabled(newMedia.count < 3)
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
                mediaErrorMessage = ""
            }
            selectedMediaItem = nil
        }
    }

    private func finishQuestionsAndSaveProfile() {
        guard newMedia.count >= 3 else {
            mediaErrorMessage = "You must upload at least 3 media items."
            return
        }

        isUploadingMedia = true

        let group = DispatchGroup()
        var uploadedMedia: [MediaItem] = []

        for media in newMedia {
            group.enter()
            uploadMedia(fileURL: media.url) { result in
                switch result {
                case .success(let url):
                    uploadedMedia.append(MediaItem(type: media.type, url: URL(string: url)!))
                case .failure(let error):
                    print("DEBUG: Failed to upload media: \(error.localizedDescription)")
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            isUploadingMedia = false

            if uploadedMedia.count < 3 {
                mediaErrorMessage = "Failed to upload all media items. Try again."
                return
            }

            userProfile.mediaItems = uploadedMedia
            userProfile.hasAnsweredQuestions = true

            saveUserProfileAndMedia {
                hasAnsweredQuestions = true
            }
        }
    }

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




    /// Save user profile to Firestore
    private func saveUserProfileAndMedia(completion: @escaping () -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()

        do {
            // We'll just overwrite the user's doc with the updated UserProfile
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
}

// MARK: - Minimal SwiftUI Thumbnails for image / video

/// Example image thumbnail using SwiftUI
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
import AVKit
struct VideoThumbnailView: View {
    let url: URL
    var body: some View {
        ZStack {
            // You can generate an actual thumbnail if desired, or use a simpler approach:
            Color.black
            Image(systemName: "play.rectangle.fill")
                .resizable()
                .foregroundColor(.white)
                .frame(width: 40, height: 30)
        }
    }
}
