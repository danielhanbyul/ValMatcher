//
//  EditProfileView.swift
//  ValMatcher
//
//  Created by Daniel Han on 7/18/24.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift

struct EditProfileView: View {
    @Binding var user: UserProfile
    @State private var newImage: UIImage?
    @State private var showingImagePicker = false
    @State private var newAge = ""
    @State private var newRank = ""
    @State private var newServer = ""
    @State private var newBestClip = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Profile Picture
            Button(action: {
                self.showingImagePicker = true
            }) {
                if let newImage = newImage {
                    Image(uiImage: newImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 150)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 4))
                        .shadow(radius: 10)
                } else {
                    Image(user.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 150)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 4))
                        .shadow(radius: 10)
                }
            }
            .sheet(isPresented: $showingImagePicker, onDismiss: loadImage) {
                ImagePicker(image: self.$newImage)
            }
            
            // Editable Fields
            TextField("Age", text: $newAge)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            TextField("Rank", text: $newRank)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            TextField("Server", text: $newServer)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            TextField("Best Clip", text: $newBestClip)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            Button(action: saveProfile) {
                Text("Save")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .padding(.top, 20)
        }
        .onAppear {
            self.newAge = user.age
            self.newRank = user.rank
            self.newServer = user.server
            self.newBestClip = user.bestClip
        }
        .padding()
        .navigationBarTitle("Edit Profile", displayMode: .inline)
    }
    
    private func loadImage() {
        // Update user's profile image
        if let newImage = newImage {
            // Implement logic to upload new image to storage and update user's image URL
            user.imageName = "newImageName" // Update with actual logic
        }
    }
    
    private func saveProfile() {
        user.age = newAge
        user.rank = newRank
        user.server = newServer
        user.bestClip = newBestClip
        // Save updated profile to Firestore
        let db = Firestore.firestore()
        do {
            try db.collection("users").document(user.id ?? "").setData(from: user)
        } catch let error {
            print("Error writing user to Firestore: \(error)")
        }
    }
}
