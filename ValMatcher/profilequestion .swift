//
//  profilequestion .swift
//  ValMatcher
//
//  Created by Ryan Kim on 6/6/24.
//

import SwiftUI
import FirebaseFirestore
import Firebase

// Define the questions globally
let profileQuestions: [String] = [
    "Who's your favorite agent to play in Valorant?",
    "Do you prefer playing as a Duelist, Initiator, Controller, or Sentinel?",
    "What’s your current rank in Valorant?",
    "Favorite game mode?",
    "What servers do you play on?",
    "What's your favorite weapon skin in Valorant?"
]

struct QuestionsView: View {
    @State private var currentQuestionIndex = 0
    @State private var answer = ""
    @State private var selectedOption: String = ""
    @State private var errorMessage = ""
    @State private var questions: [Question] = [
        Question(text: "Who's your favorite agent to play in Valorant?", type: .multipleChoice(options: ["Jett", "Sage", "Phoenix", "Brimstone", "Viper", "Omen", "Cypher", "Reyna", "Killjoy", "Skye", "Yoru", "Astra", "KAY/O", "Chamber", "Neon", "Fade", "Harbor", "Gekko"])),
        Question(text: "Do you prefer playing as a Duelist, Initiator, Controller, or Sentinel?", type: .multipleChoice(options: ["Duelist", "Initiator", "Controller", "Sentinel"])),
        Question(text: "What’s your current rank in Valorant?", type: .text),
        Question(text: "Favorite game mode?", type: .multipleChoice(options: ["Competitive", "Unrated", "Spike Rush", "Deathmatch"])),
        Question(text: "What servers do you play on?", type: .text),
        Question(text: "What's your favorite weapon skin in Valorant?", type: .text)
    ]

    @Binding var userProfile: UserProfile
    @Binding var hasAnsweredQuestions: Bool
    @State private var showTutorial = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            if currentQuestionIndex < questions.count {
                VStack(alignment: .leading, spacing: 20) {
                    Text(questions[currentQuestionIndex].text)
                        .font(.custom("AvenirNext-Bold", size: 24))
                        .padding(.top, 20)

                    if case .multipleChoice(let options) = questions[currentQuestionIndex].type {
                        Picker("Select an option", selection: $selectedOption) {
                            ForEach(options, id: \.self) { option in
                                Text(option)
                                    .font(.custom("AvenirNext-Regular", size: 18))
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .padding(.horizontal)
                        .onAppear {
                            if selectedOption.isEmpty {
                                selectedOption = options.first ?? ""
                            }
                        }
                    } else {
                        TextField("Your answer", text: $answer)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    Button(action: {
                        answerQuestion()
                    }) {
                        Text("Next")
                            .foregroundColor(.white)
                            .font(.custom("AvenirNext-Bold", size: 18))
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                }
                .padding()
            } else {
                Button(action: {
                    userProfile.hasAnsweredQuestions = true
                    saveUserProfile()
                    showTutorial = true // Navigate to TutorialView after finishing
                }) {
                    Text("Finish")
                        .foregroundColor(.white)
                        .font(.custom("AvenirNext-Bold", size: 18))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
                .fullScreenCover(isPresented: $showTutorial) {
                    TutorialView(isTutorialSeen: $userProfile.hasSeenTutorial)
                }
            }
        }
        .padding()
        .navigationBarHidden(true)
    }

    private func answerQuestion() {
        let currentQuestion = questions[currentQuestionIndex]

        if isValidAnswer(for: currentQuestion) {
            if case .multipleChoice(_) = currentQuestion.type {
                questions[currentQuestionIndex].answer = selectedOption
            } else {
                questions[currentQuestionIndex].answer = answer
            }

            userProfile.answers[currentQuestion.text] = questions[currentQuestionIndex].answer

            print("Current Answers: \(userProfile.answers)") // Debugging

            answer = ""
            selectedOption = ""
            errorMessage = ""
            currentQuestionIndex += 1

            if currentQuestionIndex < questions.count,
               case .multipleChoice(let options) = questions[currentQuestionIndex].type {
                selectedOption = options.first ?? ""
            }
        } else {
            errorMessage = "Please provide a valid answer."
        }
    }

    private func isValidAnswer(for question: Question) -> Bool {
        switch question.type {
        case .text:
            return !answer.isEmpty
        case .multipleChoice:
            return !selectedOption.isEmpty
        }
    }

    private func saveUserProfile() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        do {
            try db.collection("users").document(uid).setData(from: userProfile) { err in
                if let err = err {
                    print("Error writing user to Firestore: \(err.localizedDescription)")
                } else {
                    print("Profile saved successfully")
                    self.hasAnsweredQuestions = true
                }
            }
        } catch let error {
            print("Error writing user to Firestore: \(error.localizedDescription)")
        }
    }
}
