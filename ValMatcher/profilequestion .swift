//
//  profilequestion .swift
//  ValMatcher
//
//  Created by Ryan Kim on 6/6/24.
//

import SwiftUI

// Model for questions
enum QuestionType {
    case text
    case multipleChoice(options: [String])
}

struct Question: Identifiable {
    var id = UUID()
    var text: String
    var type: QuestionType
    var answer: String?
}

// View
struct QuestionsView: View {
    @State private var currentQuestionIndex = 0
    @State private var answer = ""
    @State private var selectedOption: String = ""
    @State private var errorMessage = ""
    @State private var questions: [Question] = [
        Question(text: "Who's your favorite agent to play in Valorant?", type: .multipleChoice(options: ["Jett", "Sage", "Phoenix", "Brimstone", "Viper", "Omen", "Cypher", "Reyna", "Killjoy", "Skye", "Yoru", "Astra", "KAY/O", "Chamber", "Neon", "Fade", "Harbor", "Gekko"])),
        Question(text: "Do you prefer playing as a Duelist, Initiator, Controller, or Sentinel?", type: .multipleChoice(options: ["Duelist", "Initiator", "Controller", "Sentinel"])),
        Question(text: "What's your go-to weapon in Valorant?", type: .multipleChoice(options: ["Classic", "Shorty", "Frenzy", "Ghost", "Sheriff", "Stinger", "Spectre", "Bucky", "Judge", "Bulldog", "Guardian", "Phantom", "Vandal", "Marshal", "Operator", "Ares", "Odin", "Knife"])),
        Question(text: "Which agent's ultimate ability do you find most satisfying to use?", type: .text),
        Question(text: "Which is your favorite map to play on in Valorant? (e.g., Ascent, Bind, Haven, etc.)", type: .multipleChoice(options: ["Ascent", "Bind", "Haven", "Split", "Icebox", "Breeze", "Fracture", "Pearl", "Lotus", "Sunset"])),
        Question(text: "Can you share a memorable clutch moment you had in Valorant?", type: .text),
        Question(text: "Do you prefer an aggressive or defensive playstyle?", type: .multipleChoice(options: ["Aggressive", "Defensive"])),
        Question(text: "What’s your current rank in Valorant?", type: .multipleChoice(options: ["Iron", "Bronze", "Silver", "Gold", "Platinum", "Diamond", "Ascendant", "Immortal", "Radiant"])),
        Question(text: "Do you enjoy playing Competitive, Unrated, Spike Rush, or Deathmatch the most?", type: .multipleChoice(options: ["Competitive", "Unrated", "Spike Rush", "Deathmatch"])),
        Question(text: "How important is team communication to you during matches?", type: .text),
        Question(text: "What's your favorite weapon skin in Valorant?", type: .text)
    ]

    var body: some View {
        NavigationView {
            VStack {
                if currentQuestionIndex < questions.count {
                    Text(questions[currentQuestionIndex].text)
                        .font(.title)
                        .padding()
                    
                    if case .multipleChoice(let options) = questions[currentQuestionIndex].type {
                        Picker("Select an option", selection: $selectedOption) {
                            ForEach(options, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .padding()
                    } else {
                        TextField("Your answer", text: $answer)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                    }
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                    }

                    Button(action: {
                        answerQuestion()
                    }) {
                        Text("Next")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                } else {
                    SummaryView(questions: questions)
                }
            }
            .navigationBarTitle("Valorant Questions", displayMode: .inline)
            .padding()
        }
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
            
            // Proceed to the next question
            answer = ""
            selectedOption = ""
            errorMessage = ""
            currentQuestionIndex += 1
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

// Summary view
struct SummaryView: View {
    var questions: [Question]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("Summary")
                    .font(.largeTitle)
                    .padding(.bottom)
                
                ForEach(questions) { question in
                    VStack(alignment: .leading) {
                        Text(question.text)
                            .font(.headline)
                        Text(question.answer ?? "No answer provided")
                            .padding(.bottom)
                    }
                    .padding(.bottom)
                }
            }
            .padding()
        }
    }
}

// Preview
struct QuestionsView_Previews: PreviewProvider {
    static var previews: some View {
        QuestionsView()
    }
}
