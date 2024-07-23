//
//  ProfileView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/15/24.
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct ProfileView: View {
    @Binding var user: UserProfile
    @Binding var isSignedIn: Bool
    var currentUserID: String
    @Environment(\.presentationMode) var presentationMode
    @State private var isEditing = false
    @State private var newImage: UIImage?
    @State private var showingImagePicker = false
    @State private var newAge = ""
    @State private var newRank = ""
    @State private var newServer = ""
    @State private var additionalImages: [String] = []
    @State private var updatedAnswers: [String: String] = [:]
    @State private var listener: ListenerRegistration?
    private var db = Firestore.firestore()

    init(user: Binding<UserProfile>, isSignedIn: Binding<Bool>, currentUserID: String) {
        self._user = user
        self._isSignedIn = isSignedIn
        self.currentUserID = currentUserID
    }

    var body: some View {
        VStack {
            // Custom Back Button
            HStack {
                Button(action: {
                    if isEditing {
                        isEditing.toggle()
                    } else {
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .imageScale(.medium)
                        Text("Back")
                            .foregroundColor(.white)
                            .font(.custom("AvenirNext-Bold", size: 18))
                    }
                }
                .padding(.top, 20)
                .padding(.leading, 20)
                
                Spacer()
                
                if !isEditing && user.id == currentUserID {
                    Button(action: {
                        isEditing.toggle()
                        initializeEditValues()
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.white)
                            .imageScale(.medium)
                    }
                    .padding(.top, 20)
                    .padding(.trailing, 20)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Profile Picture
                    if isEditing {
                        VStack {
                            ForEach(additionalImages.indices, id: \.self) { index in
                                let urlString = additionalImages[index]
                                if let url = URL(string: urlString) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                                .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.3)
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.3)
                                                .clipped()
                                                .cornerRadius(20)
                                                .background(Color.gray)
                                                .shadow(radius: 10)
                                        case .failure:
                                            Image(systemName: "photo")
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.3)
                                                .clipped()
                                                .cornerRadius(20)
                                                .background(Color.gray)
                                                .shadow(radius: 10)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                }
                            }
                            
                            Button(action: {
                                self.showingImagePicker = true
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .resizable()
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.blue)
                            }
                        }
                    } else {
                        Image(systemName: "person.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 150, height: 150)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 4))
                            .shadow(radius: 10)
                            .padding(.top, 20)
                            .padding(.bottom, 10)
                    }
                    
                    // User Information
                    VStack(alignment: .leading, spacing: 5) {
                        if isEditing {
                            TextField("Age", text: $newAge)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                            TextField("Rank", text: $newRank)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                            TextField("Server", text: $newServer)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                        } else {
                            Text("\(user.name), \(user.age)")
                                .font(.custom("AvenirNext-Bold", size: 28))
                                .foregroundColor(.white)
                            
                            Text("Rank: \(user.rank)")
                                .font(.custom("AvenirNext-Regular", size: 18))
                                .foregroundColor(.gray)
                            
                            Text("Server: \(user.server)")
                                .font(.custom("AvenirNext-Regular", size: 18))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)

                    Divider()
                        .background(Color.gray)

                    // User Answers
                    VStack(alignment: .leading, spacing: 15) {
                        ForEach(user.answers.keys.sorted(), id: \.self) { question in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(question)
                                    .font(.custom("AvenirNext-Bold", size: 20))
                                    .foregroundColor(.white)
                                if isEditing {
                                    TextField("Answer", text: Binding(
                                        get: { updatedAnswers[question] ?? user.answers[question] ?? "" },
                                        set: { updatedAnswers[question] = $0 }
                                    ))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                } else {
                                    Text(user.answers[question] ?? "No answer provided")
                                        .font(.custom("AvenirNext-Regular", size: 18))
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.bottom, 10)
                        }
                    }
                    .padding(.horizontal)
                    
                    if isEditing {
                        Button(action: saveProfile) {
                            Text("Save")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .padding(.top, 20)
                    } else {
                        // Display Additional Images
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Additional Images")
                                .font(.headline)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(user.additionalImages.indices, id: \.self) { index in
                                        let urlString = user.additionalImages[index] ?? ""
                                        if let url = URL(string: urlString),
                                           let data = try? Data(contentsOf: url),
                                           let image = UIImage(data: data) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 100, height: 100)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 2))
                                                .shadow(radius: 5)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
        )
        .navigationBarTitle("Profile", displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showingImagePicker) {
            // Your image picker view here
        }
        .onAppear {
            initializeEditValues()
            startListeningForUserUpdates()
        }
        .onDisappear {
            stopListeningForUserUpdates()
        }
    }

    func initializeEditValues() {
        newAge = user.age
        newRank = user.rank
        newServer = user.server
        additionalImages = user.additionalImages.compactMap { $0 } // Ensure non-nil URLs
        updatedAnswers = user.answers
    }

    func saveProfile() {
        // Update Firestore
        let profileRef = db.collection("users").document(currentUserID)
        profileRef.updateData([
            "name": user.name,
            "age": newAge,
            "rank": newRank,
            "server": newServer,
            "additionalImages": additionalImages,
            "answers": updatedAnswers
        ]) { error in
            if let error = error {
                print("Error updating profile: \(error)")
            } else {
                // Successfully updated
                user.age = newAge
                user.rank = newRank
                user.server = newServer
                user.additionalImages = additionalImages
                user.answers = updatedAnswers
                isEditing = false
                // Navigate back to the updated profile view
                presentationMode.wrappedValue.dismiss()
            }
        }
    }

    func startListeningForUserUpdates() {
        listener = db.collection("users").document(currentUserID).addSnapshotListener { snapshot, error in
            if let document = snapshot, document.exists {
                if let data = document.data() {
                    // Parse updated data
                    if let age = data["age"] as? String,
                       let rank = data["rank"] as? String,
                       let server = data["server"] as? String,
                       let additionalImages = data["additionalImages"] as? [String],
                       let answers = data["answers"] as? [String: String] {
                        DispatchQueue.main.async {
                            self.user.age = age
                            self.user.rank = rank
                            self.user.server = server
                            self.user.additionalImages = additionalImages
                            self.user.answers = answers
                        }
                    }
                }
            }
        }
    }

    func stopListeningForUserUpdates() {
        listener?.remove()
    }
}
