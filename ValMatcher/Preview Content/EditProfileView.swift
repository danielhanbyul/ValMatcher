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
    @State private var additionalImages: [UIImage] = []

    var body: some View {
        VStack(spacing: 20) {
            ScrollView {
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
                    
                    // Additional Images Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Additional Images")
                            .font(.headline)
                        
                        HStack {
                            ForEach(additionalImages.indices, id: \.self) { index in
                                Image(uiImage: additionalImages[index])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 2))
                                    .shadow(radius: 5)
                            }
                            Button(action: {
                                self.showingImagePicker = true
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .resizable()
                                    .frame(width: 100, height: 100)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Profile Questions
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Profile Questions")
                            .font(.headline)
                        
                        ForEach(user.answers.keys.sorted(), id: \.self) { question in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(question)
                                    .font(.subheadline)
                                TextField("Answer", text: Binding(
                                    get: { user.answers[question] ?? "" },
                                    set: { user.answers[question] = $0 }
                                ))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Save Button
                    Button(action: saveProfile) {
                        Text("Save")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .padding(.top, 20)
                }
                .padding()
            }
        }
        .onAppear {
            self.newAge = user.age
            self.newRank = user.rank
            self.newServer = user.server
        }
        .navigationBarTitle("Edit Profile", displayMode: .inline)
    }
    
    private func loadImage() {
        // Update user's profile image
        if let newImage = newImage {
            // Implement logic to upload new image to storage and update user's image URL
            user.imageName = "newImageName" // Update with actual logic
        }
        // Append new additional images
        if let newImage = newImage {
            additionalImages.append(newImage)
        }
    }
    
    private func saveProfile() {
        user.age = newAge
        user.rank = newRank
        user.server = newServer
        
        // Save updated profile to Firestore
        let db = Firestore.firestore()
        do {
            try db.collection("users").document(user.id ?? "").setData(from: user)
        } catch let error {
            print("Error writing user to Firestore: \(error)")
        }
    }
}
