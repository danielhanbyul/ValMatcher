//
//  MediaManager.swift
//  ValMatcher
//
//  Created by Daniel Han on 1/5/25.
//

import FirebaseStorage
import Foundation
import FirebaseStorage


func uploadMedia(fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
    let storage = Storage.storage()
    let storageRef = storage.reference()
    
    // Create a unique file name
    let fileName = UUID().uuidString + "." + fileURL.pathExtension
    let mediaRef = storageRef.child("media/\(fileName)")

    // Upload the file
    mediaRef.putFile(from: fileURL, metadata: nil) { metadata, error in
        if let error = error {
            print("DEBUG: Error uploading media: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }
        
        // Get the public URL
        mediaRef.downloadURL { url, error in
            if let error = error {
                print("DEBUG: Error getting download URL: \(error.localizedDescription)")
                completion(.failure(error))
            } else if let url = url {
                print("DEBUG: Media uploaded successfully. URL: \(url.absoluteString)")
                completion(.success(url.absoluteString))
            }
        }
    }
}
