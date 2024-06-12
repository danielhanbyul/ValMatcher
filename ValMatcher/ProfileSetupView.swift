//
//  ProfileSetupView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/12/24.
//

import SwiftUI
import Firebase
import FirebaseStorage
import FirebaseFirestore


struct ProfileSetupView: View {
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var age = ""
    @State private var rank = ""
    @State private var server = ""
    @State private var image: UIImage?
    @State private var imageData: Data?

    var body: some View {
        VStack {
            Spacer()
            Text("Complete Your Profile")
                .font(.custom("AvenirNext-Bold", size: 36))
                .foregroundColor(Color(red: 0.98, green: 0.27, blue: 0.29))
                .padding(.bottom, 40)
                .shadow(color: Color(red: 0.86, green: 0.24, blue: 0.29), radius: 10, x: 0, y: 5)

            VStack(alignment: .leading, spacing: 15) {
                Text("First Name")
                    .foregroundColor(.white)
                    .font(.headline)
                TextField("Enter your first name", text: $firstName)
                    .padding()
                    .background(Color(.systemGray6).opacity(0.8))
                    .cornerRadius(8.0)
                    .padding(.bottom, 20)

                Text("Last Name")
                    .foregroundColor(.white)
                    .font(.headline)
                TextField("Enter your last name", text: $lastName)
                    .padding()
                    .background(Color(.systemGray6).opacity(0.8))
                    .cornerRadius(8.0)
                    .padding(.bottom, 20)

                Text("Age")
                    .foregroundColor(.white)
                    .font(.headline)
                TextField("Enter your age", text: $age)
                    .padding()
                    .background(Color(.systemGray6).opacity(0.8))
                    .cornerRadius(8.0)
                    .padding(.bottom, 20)

                Text("Valorant Rank")
                    .foregroundColor(.white)
                    .font(.headline)
                TextField("Enter your rank", text: $rank)
                    .padding()
                    .background(Color(.systemGray6).opacity(0.8))
                    .cornerRadius(8.0)
                    .padding(.bottom, 20)

                Text("Server")
                    .foregroundColor(.white)
                    .font(.headline)
                TextField("Enter your server", text: $server)
                    .padding()
                    .background(Color(.systemGray6).opacity(0.8))
                    .cornerRadius(8.0)
                    .padding(.bottom, 20)

                Button(action: {
                    // Handle image picker action
                }) {
                    Text("Upload Profile Picture")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 220, height: 60)
                        .background(Color(red: 0.98, green: 0.27, blue: 0.29))
                        .cornerRadius(15.0)
                        .shadow(color: Color(red: 0.98, green: 0.27, blue: 0.29).opacity(0.5), radius: 10, x: 0, y: 10)
                }
                .padding(.top, 20)
            }
            .padding(.horizontal, 30)

            Button(action: completeProfile) {
                Text("Complete Profile")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 220, height: 60)
                    .background(Color(red: 0.98, green: 0.27, blue: 0.29))
                    .cornerRadius(15.0)
                    .shadow(color: Color(red: 0.98, green: 0.27, blue: 0.29).opacity(0.5), radius: 10, x: 0, y: 10)
            }
            .padding(.top, 20)

            Spacer()
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
        )
    }

    func completeProfile() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        var data: [String: Any] = [
            "firstName": firstName,
            "lastName": lastName,
            "age": age,
            "rank": rank,
            "server": server
        ]

        if let imageData = imageData {
            let storageRef = Storage.storage().reference().child("profile_pictures").child(uid)
            storageRef.putData(imageData, metadata: nil) { (metadata, error) in
                if let error = error {
                    print("Error uploading image: \(error.localizedDescription)")
                    return
                }

                storageRef.downloadURL { (url, error) in
                    if let error = error {
                        print("Error getting download URL: \(error.localizedDescription)")
                        return
                    }

                    if let profileImageUrl = url?.absoluteString {
                        data["profileImageUrl"] = profileImageUrl
                        db.collection("users").document(uid).updateData(data) { error in
                            if let error = error {
                                print("Error updating profile: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        } else {
            db.collection("users").document(uid).updateData(data) { error in
                if let error = error {
                    print("Error updating profile: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct ProfileSetupView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSetupView()
            .preferredColorScheme(.dark) // Assuming dark mode preference
    }
}
