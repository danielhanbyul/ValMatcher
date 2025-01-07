//
//  MediaManager.swift
//  ValMatcher
//
//  Created by Daniel Han on 1/5/25.
//

import FirebaseStorage
import Foundation
import FirebaseStorage
import FirebaseAuth

func uploadMedia(fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
    guard let userID = Auth.auth().currentUser?.uid else {
        completion(.failure(NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
        return
    }

    let storage = Storage.storage()
    let mediaID = UUID().uuidString
    let storageRef = storage.reference().child("users/\(userID)/media/\(mediaID)")

    // Determine content type
    let fileExtension = fileURL.pathExtension.lowercased()
    let contentType: String
    if ["mp4", "mov"].contains(fileExtension) { // Include mov files
        contentType = "video/\(fileExtension)"
        print("DEBUG: Detected video file for upload.")
    } else if ["jpg", "jpeg", "png"].contains(fileExtension) {
        contentType = "image/jpeg"
        print("DEBUG: Detected image file for upload.")
    } else {
        let error = NSError(domain: "UploadError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Unsupported file type: \(fileExtension)"])
        print("DEBUG: Unsupported file type: \(fileExtension)")
        completion(.failure(error))
        return
    }
    print("DEBUG: File URL: \(fileURL), Content Type: \(contentType)")

    // Set metadata
    let metadata = StorageMetadata()
    metadata.contentType = contentType

    // Upload the file
    let uploadTask = storageRef.putFile(from: fileURL, metadata: metadata) { metadata, error in
        if let error = error {
            print("DEBUG: Upload error: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }

        storageRef.downloadURL { url, error in
            if let error = error {
                print("DEBUG: Failed to retrieve download URL: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            if let downloadURL = url?.absoluteString {
                print("DEBUG: File uploaded successfully. URL: \(downloadURL)")
                completion(.success(downloadURL))
            } else {
                completion(.failure(NSError(domain: "UploadError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve download URL"])))
            }
        }
    }

    // Log upload progress
    uploadTask.observe(.progress) { snapshot in
        if let progress = snapshot.progress {
            let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount) * 100
            print("DEBUG: Upload progress: \(percentComplete)%")
        }
    }
}
