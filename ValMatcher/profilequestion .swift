//
//  profilequestion .swift
//  ValMatcher
//
//  Created by Ryan Kim on 6/6/24.
//

import SwiftUI

// Model for questions
struct Question: Identifiable {
    var id = UUID()
    var text: String
}

// View
struct QuestionsView: View {
    @State private var currentQuestionIndex = 0
    @State private var answer = ""

    let questions = [
        Question(text: "Who's your favorite agent to play in Valorant? (e.g., Jett, Sage, Phoenix, etc.)"),
        Question(text: "Do you prefer playing as a Duelist, Initiator, Controller, or Sentinel?"),
        Question(text: "What's your go-to weapon in Valorant?"),
        Question(text: "Which agent's ultimate ability do you find most satisfying to use?"),
        Question(text: "Which is your favorite map to play on in Valorant? (e.g., Ascent, Bind, Haven, etc.)"),
        Question(text: "Can you share a memorable clutch moment you had in Valorant?"),
        Question(text: "Do you prefer an aggressive or defensive playstyle?"),
        Question(text: "What’s your current rank in Valorant?"),
        Question(text: "Do you enjoy playing Competitive, Unrated, Spike Rush, or Deathmatch the most?"),
        Question(text: "How important is team communication to you during matches?"),
        Question(text: "What's your favorite weapon skin in Valorant?")
    ]

    var body: some View {
        NavigationView {
            VStack {
                if currentQuestionIndex < questions.count {
                    Text(questions[currentQuestionIndex].text)
                        .font(.title)
                        .padding()

                    TextField("Your answer", text: $answer)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()

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
                    Text("Thank you for answering all the questions!")
                        .font(.title)
                        .padding()
                }
            }
            .navigationBarTitle("Valorant Questions", displayMode: .inline)
            .padding()
        }
    }

    private func answerQuestion() {
        // Store the answer or perform any necessary actions
        // For now, just proceed to the next question
        answer = ""
        currentQuestionIndex += 1
    }
}

// Preview
struct QuestionsView_Previews: PreviewProvider {
    static var previews: some View {
        QuestionsView()
    }
}
