//
//  UserProfileView.swift
//  ValMatcher
//
//  Created by Daniel Han on 7/22/24.
//

import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseStorage
import Combine

class UserProfileViewModel: ObservableObject {
    @Published var user: UserProfile
    @Published var chats: [Chat] = []
    
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init(user: UserProfile) {
        self.user = user
        fetchChats()
    }

    // -------------------------------------------
    // Fetch chats for the current user
    // -------------------------------------------
    func fetchChats() {
        listener = db.collection("chats")
            .whereField("participants", arrayContains: user.id ?? "")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("No documents")
                    return
                }

                DispatchQueue.main.async {
                    self?.chats = documents.compactMap { doc -> Chat? in
                        try? doc.data(as: Chat.self)
                    }
                }
            }
    }

    // -------------------------------------------
    // Fetch unread message count for a specific chat
    // -------------------------------------------
    func fetchUnreadMessagesCount(chatId: String, completion: @escaping (Int) -> Void) {
        db.collection("chats").document(chatId).collection("messages")
            .whereField("isRead", isEqualTo: false)
            .whereField("recipientId", isEqualTo: user.id ?? "")
            .addSnapshotListener { snapshot, error in
                if let snapshot = snapshot {
                    completion(snapshot.documents.count)
                } else {
                    completion(0)
                }
            }
    }

    // -------------------------------------------
    // Update user profile (previously overwrote everything)
    // Now calls saveUserProfile() which does partial updates
    // -------------------------------------------
    func updateUserProfile(
        newAge: String,
        newRank: String,
        newServer: String,
        mediaItems: [MediaItem],
        updatedAnswers: [String: String]
    ) {
        // Update the local user so the UI stays in sync
        if let ageInt = Int(newAge) {
            user.age = ageInt
        }

        user.rank = newRank
        user.server = newServer
        user.mediaItems = mediaItems
        user.answers = updatedAnswers

        // Saves to Firestore (partial update)
        saveUserProfile()
    }

    // -------------------------------------------
    // Add a new media item and upload to Firebase Storage
    // -------------------------------------------
    func addMedia(media: MediaItem) {
        guard let userId = user.id else { return }

        if media.type == .image {
            uploadImage(urlString: media.url.absoluteString,
                        path: "media/\(userId)/\(UUID().uuidString)") { [weak self] url in
                self?.addMediaItem(type: .image, url: url)
            }
        } else if media.type == .video {
            uploadVideo(urlString: media.url.absoluteString,
                        path: "media/\(userId)/\(UUID().uuidString)") { [weak self] url in
                self?.addMediaItem(type: .video, url: url)
            }
        }
    }

    private func addMediaItem(type: MediaType, url: URL) {
        // Update local user
        user.mediaItems = (user.mediaItems ?? []) + [MediaItem(type: type, url: url)]
        // Partial update to Firestore
        saveUserProfile()
    }

    // -------------------------------------------
    // Upload an image to Firebase Storage
    // -------------------------------------------
    func uploadImage(urlString: String, path: String, completion: @escaping (URL) -> Void) {
        let storageRef = Storage.storage().reference().child(path)
        guard let imageData = try? Data(contentsOf: URL(string: urlString)!) else { return }
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        storageRef.putData(imageData, metadata: metadata) { _, error in
            if let error = error {
                print("Error uploading image: \(error)")
                return
            }
            storageRef.downloadURL { url, error in
                if let url = url {
                    completion(url)
                } else if let error = error {
                    print("Error getting download URL: \(error)")
                }
            }
        }
    }

    // -------------------------------------------
    // Upload a video to Firebase Storage
    // -------------------------------------------
    func uploadVideo(urlString: String, path: String, completion: @escaping (URL) -> Void) {
        let storageRef = Storage.storage().reference().child(path)
        let videoURL = URL(string: urlString)!
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"

        storageRef.putFile(from: videoURL, metadata: metadata) { _, error in
            if let error = error {
                print("Error uploading video: \(error)")
                return
            }
            storageRef.downloadURL { url, error in
                if let url = url {
                    completion(url)
                } else if let error = error {
                    print("Error getting download URL: \(error)")
                }
            }
        }
    }

    // -------------------------------------------
    // SAVE USER PROFILE - PARTIAL UPDATE
    // Instead of setData(from: user), we do setData(..., merge: true)
    // so we only overwrite the fields we specify, preserving others like "name".
    // -------------------------------------------
    private func saveUserProfile() {
        guard let userId = user.id else { return }

        // Create a dictionary of the fields we want to ensure are updated.
        let updatedData: [String: Any] = [
            "name": user.name,
            "rank": user.rank,
            "imageName": user.imageName,
            "age": user.age,
            "server": user.server,
            "answers": user.answers,
            "hasAnsweredQuestions": user.hasAnsweredQuestions,
            "mediaItems": user.mediaItems?.map { [
                "type": $0.type.rawValue,
                "url": $0.url.absoluteString
            ]} ?? [],
            "createdAt": user.createdAt ?? Timestamp(),
            "hasSeenTutorial": user.hasSeenTutorial,
            "profileUpdated": true // Set profileUpdated to true when updating
        ]

        let docRef = db.collection("users").document(userId)
        docRef.setData(updatedData, merge: true) { error in
            if let error = error {
                print("Error saving user profile (partial update): \(error)")
            } else {
                print("Successfully updated user profile with partial data.")
            }
        }
    }
    


    deinit {
        listener?.remove()  // Clean up Firestore listener
    }
}
