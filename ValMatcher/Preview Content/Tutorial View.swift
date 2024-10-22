//
//  Tutorial View.swift
//  ValMatcher
//
//  Created by Daniel Han on 10/22/24.
//

import SwiftUI

struct TutorialView: View {
    @Binding var isTutorialSeen: Bool
    @State private var currentCardIndex = 0
    @State private var interactionResult: ContentView.InteractionResult? = nil
    
    // Adjustable space variables
    @State private var titleToCardSpacing: CGFloat = 0.2 // Percentage of screen height
    @State private var cardToInstructionsSpacing: CGFloat = 0.19  // Percentage of screen height

    let tutorialCards: [UserProfile] = [
        UserProfile(id: "1", name: "User1", rank: "Silver", imageName: "", age: "21", server: "NA", answers: [:], hasAnsweredQuestions: true, mediaItems: []),
        UserProfile(id: "2", name: "User2", rank: "Gold", imageName: "", age: "24", server: "EU", answers: [:], hasAnsweredQuestions: true, mediaItems: [])
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)

                VStack(spacing: 20) {
                    Text("Welcome to ValMatcher!")
                        .font(.custom("AvenirNext-Bold", size: geometry.size.width * 0.06))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, geometry.size.height * 0.015)

                    // Adjustable space between title and UserCard
                    Spacer().frame(height: geometry.size.height * titleToCardSpacing)

                    ZStack {
                        if currentCardIndex < tutorialCards.count {
                            UserCardView(user: tutorialCards[currentCardIndex])
                                .frame(width: geometry.size.width * 0.65, height: geometry.size.height * 0.2)  // Smaller card size for better fit
                                .gesture(
                                    DragGesture(minimumDistance: 20)
                                        .onEnded { gesture in
                                            if gesture.translation.width < -100 {
                                                passAction()
                                            } else if gesture.translation.width > 100 {
                                                likeAction()
                                            }
                                        }
                                )
                                .gesture(
                                    TapGesture(count: 2)
                                        .onEnded {
                                            likeAction()
                                        }
                                )
                        }
                        if let result = interactionResult {
                            interactionResultView(result)
                        }
                    }
                    .frame(height: geometry.size.height * 0.2)  // Adjusted frame to match smaller card size

                    // Adjustable space between UserCard and "How to use the app" section
                    Spacer().frame(height: geometry.size.height * cardToInstructionsSpacing)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("How to use the app:")
                            .font(.custom("AvenirNext-Bold", size: geometry.size.width * 0.04))
                            .foregroundColor(.white)

                        Text("- Swipe left to skip")
                            .font(.custom("AvenirNext-Regular", size: geometry.size.width * 0.03))
                            .foregroundColor(.white)

                        Text("- Swipe right or double-tap to like")
                            .font(.custom("AvenirNext-Regular", size: geometry.size.width * 0.03))
                            .foregroundColor(.white)

                        Text("- If two users like each other, you'll match and can chat!")
                            .font(.custom("AvenirNext-Regular", size: geometry.size.width * 0.03))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)  // Ensure text isn't cut off
                    }
                    .padding(.horizontal, geometry.size.width * 0.1)
                    .padding(.bottom, geometry.size.height * 0.01)

                    Button(action: {
                        isTutorialSeen = true
                    }) {
                        Text("Got it!")
                            .font(.custom("AvenirNext-Bold", size: geometry.size.width * 0.05))
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }
                    .padding(.horizontal, geometry.size.width * 0.1)
                    .padding(.bottom, geometry.size.height * 0.05)
                }
            }
        }
    }

    private func passAction() {
        interactionResult = .passed
        withAnimation {
            moveToNextCard()
        }
    }

    private func likeAction() {
        interactionResult = .liked
        withAnimation {
            moveToNextCard()
        }
    }

    private func moveToNextCard() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            interactionResult = nil
            currentCardIndex = (currentCardIndex + 1) % tutorialCards.count
        }
    }

    private func interactionResultView(_ result: ContentView.InteractionResult) -> some View {
        Group {
            if result == .liked {
                Image(systemName: "heart.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.green)
                    .transition(.opacity)
            } else if result == .passed {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.red)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: result)
    }
}

struct TutorialView_Previews: PreviewProvider {
    static var previews: some View {
        TutorialView(isTutorialSeen: .constant(false))  // Preview with constant binding
            .previewDevice("iPhone 13")
    }
}
