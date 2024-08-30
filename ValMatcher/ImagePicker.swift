//
//  ImagePicker.swift
//  ValMatcher
//
//  Created by Daniel Han on 7/18/24.
//

import SwiftUI
import PhotosUI
import MobileCoreServices

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedMedia: [MediaItem]

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: ImagePicker

        init(parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            for result in results {
                if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    result.itemProvider.loadObject(ofClass: UIImage.self) { (image, error) in
                        if let image = image as? UIImage {
                            DispatchQueue.main.async {
                                if let url = self.saveImageToTemporaryDirectory(image: image) {
                                    self.parent.selectedMedia.append(MediaItem(url: url.absoluteString, type: .image))
                                }
                            }
                        }
                    }
                } else if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { (url, error) in
                        if let url = url {
                            // Check if the file exists
                            if FileManager.default.fileExists(atPath: url.path) {
                                // Move video to a stable directory
                                DispatchQueue.main.async {
                                    if let stableURL = self.copyVideoToDocumentsDirectory(url: url) {
                                        self.parent.selectedMedia.append(MediaItem(url: stableURL.absoluteString, type: .video))
                                    } else {
                                        print("Failed to copy video to documents directory.")
                                    }
                                }
                            } else {
                                print("Video file does not exist at path: \(url.path)")
                            }
                        } else {
                            print("Error loading video: \(error?.localizedDescription ?? "Unknown error")")
                        }
                    }
                }
            }
        }

        private func saveImageToTemporaryDirectory(image: UIImage) -> URL? {
            let fileName = UUID().uuidString + ".jpg"
            let temporaryDirectoryURL = FileManager.default.temporaryDirectory
            let fileURL = temporaryDirectoryURL.appendingPathComponent(fileName)

            if let imageData = image.jpegData(compressionQuality: 0.8) {
                do {
                    try imageData.write(to: fileURL)
                    return fileURL
                } catch {
                    print("Error saving image to temporary directory: \(error)")
                }
            }
            return nil
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
                print("Error copying video to documents directory: \(error)")
                return nil
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .any(of: [.images, .videos])
        config.selectionLimit = 4 - selectedMedia.count // Allow selecting only the remaining slots

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
}


struct MediaItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var url: String
    var type: MediaType
}

enum MediaType: String, Codable {
    case image
    case video
}
