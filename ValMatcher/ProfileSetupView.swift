//
//  ProfileSetupView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/12/24.
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct ProfileSetupView: View {
    @Binding var currentUser: UserProfile?
    @Binding var isSignedIn: Bool

    @State private var currentQuestionIndex = 0
    @State private var answers: [String: String] = [:]
    @State private var isLoading = false
    @State private var errorMessage = ""

    private let questions = [
        "Who's your favorite agent to play in Valorant?",
        "Do you prefer playing as a Duelist, Initiator, Controller, or Sentinel?",
        "What's your current rank in Valorant?",
        "Favorite game mode?",
        "What servers do you play on? (ex: NA, N. California)",
        "What's your favorite weapon skin in Valorant?"
    ]

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Saving...")
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    Text(questions[currentQuestionIndex])
                        .font(.headline)
                        .padding()

                    TextField("Answer", text: Binding(
                        get: { answers[questions[currentQuestionIndex]] ?? "" },
                        set: { answers[questions[currentQuestionIndex]] = $0 }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                    HStack {
                        Spacer()
                        Button(action: nextQuestion) {
                            Text(currentQuestionIndex == questions.count - 1 ? "Finish" : "Next")
                                .bold()
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        Spacer()
                    }
                }
                .padding()
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .navigationBarTitle("Profile Setup", displayMode: .inline)
    }

    private func nextQuestion() {
        if currentQuestionIndex < questions.count - 1 {
            currentQuestionIndex += 1
        } else {
            saveProfile()
        }
    }

    private func saveProfile() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Unable to fetch user ID"
            return
        }

        isLoading = true

        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "answers": answers,
            "hasAnsweredQuestions": true
        ]) { error in
            if let error = error {
                errorMessage = "Failed to save profile: \(error.localizedDescription)"
                isLoading = false
                return
            }

            self.currentUser?.answers = self.answers
            self.currentUser?.hasAnsweredQuestions = true
            self.isSignedIn = true
        }
    }
}

struct ProfileSetupView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSetupView(currentUser: .constant(UserProfile(
            name: "Preview User",
            rank: "Gold 3",
            imageName: "preview",
            age: 24,
            server: "NA",
            answers: [:],
            hasAnsweredQuestions: false,
            mediaItems: []  // Replace additionalImages with mediaItems
        )), isSignedIn: .constant(true))
    }
}
