//
//  UserProfileView.swift
//  ValMatcher
//
//  Created by Daniel Han on 7/22/24.
//

import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseStorage

class UserProfileViewModel: ObservableObject {
    @Published var user: UserProfile
    @Published var chats: [Chat] = []

    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init(user: UserProfile) {
        self.user = user
        fetchChats()
    }

    func fetchChats() {
        listener = db.collection("chats")
            .whereField("participants", arrayContains: user.id ?? "")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("No documents")
                    return
                }

                self?.chats = documents.compactMap { doc -> Chat? in
                    try? doc.data(as: Chat.self)
                }
            }
    }

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

    deinit {
        listener?.remove()
    }

    func updateUserProfile(newAge: String, newRank: String, newServer: String, mediaItems: [MediaItem], updatedAnswers: [String: String]) {
        user.age = newAge
        user.rank = newRank
        user.server = newServer
        user.mediaItems = mediaItems  // Store MediaItem objects
        user.answers = updatedAnswers

        guard let userId = user.id else { return }
        do {
            try db.collection("users").document(userId).setData(from: user)
        } catch let error {
            print("Error writing user to Firestore: \(error)")
        }
    }

    func addMedia(media: MediaItem) {
        guard let userId = user.id else { return }

        if media.type == .image {
            uploadImage(urlString: media.url.absoluteString, path: "media/\(userId)/\(UUID().uuidString)") { [weak self] url in
                guard let strongSelf = self else { return }
                // Safely unwrap mediaItems and then append
                if var mediaItems = strongSelf.user.mediaItems {
                    mediaItems.append(MediaItem(type: .image, url: url))
                    strongSelf.user.mediaItems = mediaItems
                } else {
                    strongSelf.user.mediaItems = [MediaItem(type: .image, url: url)]
                }
                strongSelf.saveUserProfile()
            }
        } else if media.type == .video {
            uploadVideo(urlString: media.url.absoluteString, path: "media/\(userId)/\(UUID().uuidString)") { [weak self] url in
                guard let strongSelf = self else { return }
                // Safely unwrap mediaItems and then append
                if var mediaItems = strongSelf.user.mediaItems {
                    mediaItems.append(MediaItem(type: .video, url: url))
                    strongSelf.user.mediaItems = mediaItems
                } else {
                    strongSelf.user.mediaItems = [MediaItem(type: .video, url: url)]
                }
                strongSelf.saveUserProfile()
            }
        }
    }

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

    private func saveUserProfile() {
        guard let userId = user.id else { return }
        do {
            try db.collection("users").document(userId).setData(from: user)
        } catch let error {
            print("Error saving user profile: \(error)")
        }
    }
}
