//
//  Image:VideoPicker.swift
//  ValMatcher
//
//  Created by Daniel Han on 7/8/24.
//

import SwiftUI
import Firebase
import FirebaseStorage
import FirebaseFirestore
import FirebaseFirestoreSwift

struct PostMediaView: View {
    @State private var caption: String = ""
    @State private var selectedImage: UIImage? = nil
    @State private var selectedVideoURL: URL? = nil
    @State private var isShowingImagePicker = false
    @State private var isShowingVideoPicker = false
    @State private var mediaType: String = ""
    
    var body: some View {
        VStack {
            TextField("Enter caption", text: $caption)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            
            Button(action: {
                isShowingImagePicker = true
            }) {
                Text("Select Image")
            }
            .padding()
            
            Button(action: {
                isShowingVideoPicker = true
            }) {
                Text("Select Video")
            }
            .padding()
            
            if let selectedImage = selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
            } else if let selectedVideoURL = selectedVideoURL {
                // Display video thumbnail or placeholder
                Text("Video selected")
                    .frame(height: 200)
                    .background(Color.gray)
            }
            
            Button(action: {
                uploadMedia()
            }) {
                Text("Upload")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(selectedImage: $selectedImage, mediaType: $mediaType)
        }
        .sheet(isPresented: $isShowingVideoPicker) {
            VideoPicker(selectedVideoURL: $selectedVideoURL, mediaType: $mediaType)
        }
    }
    
    func uploadMedia() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Error: User not authenticated")
            return
        }
        
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let mediaName = UUID().uuidString
        var mediaRef: StorageReference
        
        if mediaType == "image", let selectedImage = selectedImage, let imageData = selectedImage.jpegData(compressionQuality: 0.8) {
            mediaRef = storageRef.child("images/\(mediaName).jpg")
            mediaRef.putData(imageData, metadata: nil) { metadata, error in
                if let error = error {
                    print("Error uploading image: \(error)")
                    return
                }
                mediaRef.downloadURL { url, error in
                    if let error = error {
                        print("Error getting image URL: \(error)")
                        return
                    }
                    if let url = url {
                        savePostData(mediaUrl: url.absoluteString, userId: currentUserID)
                    }
                }
            }
        } else if mediaType == "video", let selectedVideoURL = selectedVideoURL {
            mediaRef = storageRef.child("videos/\(mediaName).mov")
            mediaRef.putFile(from: selectedVideoURL, metadata: nil) { metadata, error in
                if let error = error {
                    print("Error uploading video: \(error)")
                    return
                }
                mediaRef.downloadURL { url, error in
                    if let error = error {
                        print("Error getting video URL: \(error)")
                        return
                    }
                    if let url = url {
                        savePostData(mediaUrl: url.absoluteString, userId: currentUserID)
                    }
                }
            }
        }
    }
    
    func savePostData(mediaUrl: String, userId: String) {
        let db = Firestore.firestore()
        let postData: [String: Any] = [
            "userId": userId,
            "timestamp": Timestamp(),
            "mediaType": mediaType,
            "mediaUrl": mediaUrl,
            "caption": caption
        ]
        
        db.collection("posts").addDocument(data: postData) { error in
            if let error = error {
                print("Error saving post data: \(error)")
            } else {
                print("Post data saved successfully")
                // Clear inputs after successful upload
                caption = ""
                selectedImage = nil
                selectedVideoURL = nil
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var mediaType: String
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.mediaTypes = ["public.image"]
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.selectedImage = uiImage
                parent.mediaType = "image"
            }
            picker.dismiss(animated: true)
        }
    }
}

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var selectedVideoURL: URL?
    @Binding var mediaType: String
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.mediaTypes = ["public.movie"]
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: VideoPicker
        
        init(_ parent: VideoPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let url = info[.mediaURL] as? URL {
                parent.selectedVideoURL = url
                parent.mediaType = "video"
            }
            picker.dismiss(animated: true)
        }
    }
}
