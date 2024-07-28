//
//  UserProfileView.swift
//  ValMatcher
//
//  Created by Daniel Han on 7/22/24.
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseStorage

class UserProfileViewModel: ObservableObject {
    @Published var user: UserProfile
    
    init(user: UserProfile) {
        self.user = user
    }
    
    func updateUserProfile(newAge: String, newRank: String, newServer: String, additionalImages: [String], updatedAnswers: [String: String]) {
        // Update local user profile
        user.age = newAge
        user.rank = newRank
        user.server = newServer
        user.additionalImages = additionalImages
        user.answers = updatedAnswers
        
        // Save to Firestore
        guard let userId = user.id else { return }
        let db = Firestore.firestore()
        do {
            try db.collection("users").document(userId).setData(from: user)
        } catch let error {
            print("Error writing user to Firestore: \(error)")
        }
    }
    
    func addMedia(media: MediaItem) {
        // Upload media to storage and get URL
        // Example storage path: "media/\(user.id)/\(UUID().uuidString)"
        guard let userId = user.id else { return }
        
        if let image = media.image {
            uploadImage(image: image, path: "media/\(userId)/\(UUID().uuidString)") { [weak self] url in
                self?.user.additionalImages.append(url.absoluteString)
                self?.saveUserProfile()
            }
        } else if let videoURL = media.videoURL {
            uploadVideo(url: videoURL, path: "media/\(userId)/\(UUID().uuidString)") { [weak self] url in
                self?.user.additionalImages.append(url.absoluteString)
                self?.saveUserProfile()
            }
        }
    }
    
    public func uploadImage(image: UIImage, path: String, completion: @escaping (URL) -> Void) {
        let storageRef = Storage.storage().reference().child(path)
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
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
    
    public func uploadVideo(url: URL, path: String, completion: @escaping (URL) -> Void) {
        let storageRef = Storage.storage().reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        
        storageRef.putFile(from: url, metadata: metadata) { _, error in
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
        let db = Firestore.firestore()
        do {
            try db.collection("users").document(userId).setData(from: user)
        } catch let error {
            print("Error saving user profile: \(error)")
        }
    }
}
