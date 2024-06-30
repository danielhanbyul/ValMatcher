//
//  profilequestion .swift
//  ValMatcher
//
//  Created by Ryan Kim on 6/6/24.
//

import SwiftUI

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
        Question(text: "What servers do you play on? (ex: NA, N. California)", type: .text),
        Question(text: "What's your favorite weapon skin in Valorant?", type: .text)
    ]

    @Binding var userProfile: UserProfile
    @State private var navigateToMain = false  // State to control navigation

    init(userProfile: Binding<UserProfile>) {
        self._userProfile = userProfile
    }

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
                    // Save userProfile to persistent storage if needed
                    navigateToMain = true // Set flag to navigate to ContentView
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
                .background(
                    NavigationLink(
                        destination: ContentView(),
                        isActive: $navigateToMain,
                        label: { EmptyView() }
                    ).hidden() // Hide the actual NavigationLink view
                )
            }
        }
        .navigationBarTitle("Valorant Questions", displayMode: .inline)
        .padding()
    }

    private func answerQuestion() {
        let currentQuestion = questions[currentQuestionIndex]

        if isValidAnswer(for: currentQuestion) {
            // Store the answer
            if case .multipleChoice(_) = currentQuestion.type {
                questions[currentQuestionIndex].answer = selectedOption
            } else {
                questions[currentQuestionIndex].answer = answer
            }

            // Save the answer to the user profile
            userProfile.answers[currentQuestion.text] = questions[currentQuestionIndex].answer

            // Proceed to the next question
            answer = ""
            selectedOption = ""
            errorMessage = ""
            currentQuestionIndex += 1

            // Set the default value for the next question if it's multiple choice
            if currentQuestionIndex < questions.count,
               case .multipleChoice(let options) = questions[currentQuestionIndex].type {
                selectedOption = options.first ?? ""
            }
        } else {
            // Show error message
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
}

// Preview
struct QuestionsView_Previews: PreviewProvider {
    static var previews: some View {
        QuestionsView(userProfile: .constant(UserProfile(name: "John Doe", rank: "Platinum 1", imageName: "john", age: "25", server: "NA", bestClip: "clip1", answers: [:], hasAnsweredQuestions: false)))
    }
}
