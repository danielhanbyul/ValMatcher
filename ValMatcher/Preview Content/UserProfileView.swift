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
        listener = db.collection("chats").whereField("participants", arrayContains: user.id ?? "").addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else {
                print("No documents")
                return
            }

            self.chats = documents.compactMap { doc -> Chat? in
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

    func updateUserProfile(newAge: String, newRank: String, newServer: String, additionalImages: [String], updatedAnswers: [String: String]) {
        user.age = newAge
        user.rank = newRank
        user.server = newServer
        user.additionalImages = additionalImages
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

    func uploadImage(image: UIImage, path: String, completion: @escaping (URL) -> Void) {
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

    func uploadVideo(url: URL, path: String, completion: @escaping (URL) -> Void) {
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
        do {
            try db.collection("users").document(userId).setData(from: user)
        } catch let error {
            print("Error saving user profile: \(error)")
        }
    }
}


import SwiftUI

struct ChatListView: View {
    @ObservedObject var viewModel: UserProfileViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Chats")
                .font(.custom("AvenirNext-Bold", size: 20))
                .foregroundColor(.white)
                .padding(.leading)
            
            ForEach(viewModel.chats) { chat in
                ChatRowView(viewModel: viewModel, chat: chat)
            }
        }
        .padding()
    }
}

struct ChatRowView: View {
    @ObservedObject var viewModel: UserProfileViewModel
    var chat: Chat
    @State private var unreadMessagesCount: Int = 0
    
    var body: some View {
        HStack {
            Text(chat.id ?? "Chat")
                .foregroundColor(.white)
                .font(.custom("AvenirNext-Regular", size: 18))
            Spacer()
            if unreadMessagesCount > 0 {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
        .onAppear {
            viewModel.fetchUnreadMessagesCount(chatId: chat.id!) { count in
                self.unreadMessagesCount = count
            }
        }
    }
}
