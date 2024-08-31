//
//  ImagePicker.swift
//  ValMatcher
//
//  Created by Daniel Han on 7/18/24.
//

import Foundation
import SwiftUI
import UIKit
import Firebase
import FirebaseStorage

enum ImageUploadError: Error {
    case compressionFailed
    case urlNil
}

enum MediaType: String, Codable, Equatable {
    case image
    case video
}

struct MediaItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var type: MediaType
    var url: URL
}

class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    let parent: ImagePicker
    init(parent: ImagePicker) {
        self.parent = parent
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let image = info[.originalImage] as? UIImage {
            parent.selectedMediaItem = MediaItem(type: .image, url: saveToDocumentsDirectory(image: image)!)
        } else if let videoURL = info[.mediaURL] as? URL {
            parent.selectedMediaItem = MediaItem(type: .video, url: videoURL)
        }
        picker.dismiss(animated: true)
    }
    
    private func saveToDocumentsDirectory(image: UIImage) -> URL? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(UUID().uuidString + ".jpg")
        
        if let data = image.jpegData(compressionQuality: 0.8) {
            do {
                try data.write(to: fileURL)
                return fileURL
            } catch {
                print("Error saving image to documents directory: \(error)")
                return nil
            }
        }
        return nil
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedMediaItem: MediaItem?
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.mediaTypes = ["public.image", "public.movie"] // Allow both images and videos
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
}
