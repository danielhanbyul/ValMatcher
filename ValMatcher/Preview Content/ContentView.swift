//
//  ContentView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/6/24.
//

import SwiftUI
import Foundation

// View
struct ContentView: View {
    @State private var users = [
        UserProfile(name: "Alice", rank: "Bronze 1", imageName: "alice", age: "21", server: "NA", bestClip: "clip1", answers: [:]),
        UserProfile(name: "Bob", rank: "Silver 2", imageName: "bob", age: "22", server: "EU", bestClip: "clip2", answers: [:]),
        UserProfile(name: "Charlie", rank: "Gold 3", imageName: "charlie", age: "23", server: "NA", bestClip: "clip3", answers: [:]),
        UserProfile(name: "David", rank: "Platinum 1", imageName: "david", age: "24", server: "NA", bestClip: "clip4", answers: [:]),
        UserProfile(name: "Eva", rank: "Diamond 2", imageName: "eva", age: "25", server: "NA", bestClip: "clip5", answers: [:]),
        UserProfile(name: "Frank", rank: "Ascendant 3", imageName: "frank", age: "26", server: "EU", bestClip: "clip6", answers: [:]),
        UserProfile(name: "Grace", rank: "Immortal 1", imageName: "grace", age: "27", server: "NA", bestClip: "clip7", answers: [:]),
        UserProfile(name: "Hannah", rank: "Bronze 3", imageName: "hannah", age: "28", server: "NA", bestClip: "clip8", answers: [:]),
        UserProfile(name: "Ivy", rank: "Radiant", imageName: "ivy", age: "29", server: "NA", bestClip: "clip9", answers: [:]),
        UserProfile(name: "Jack", rank: "Silver 1", imageName: "jack", age: "30", server: "EU", bestClip: "clip10", answers: [:])
    ]
    @State private var currentIndex = 0
    @State private var offset = CGSize.zero
    @State private var interactionResult: InteractionResult? = nil

    enum InteractionResult {
        case liked
        case passed
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom) // #042e27 and #364966 equivalent
                    .edgesIgnoringSafeArea(.all)

                VStack {
                    if currentIndex < users.count {
                        ZStack {
                            UserCardView(user: users[currentIndex])
                                .gesture(
                                    DragGesture()
                                        .onChanged { gesture in
                                            self.offset = gesture.translation
                                        }
                                        .onEnded { gesture in
                                            if self.offset.width < -100 {
                                                self.dislikeAction()
                                            } else if self.offset.width > 100 {
                                                self.likeAction()
                                            }
                                            self.offset = .zero
                                        }
                                )
                                .gesture(
                                    TapGesture(count: 2)
                                        .onEnded {
                                            self.likeAction()
                                        }
                                )
                                .offset(x: self.offset.width * 1.5, y: self.offset.height)
                                .animation(.spring())
                                .transition(.slide)

                            if let result = interactionResult {
                                if result == .liked {
                                    Image(systemName: "heart.fill")
                                        .resizable()
                                        .frame(width: 100, height: 100)
                                        .foregroundColor(.green)
                                        .transition(.opacity)
                                } else if result == .passed {
                                    Image(systemName: "xmark.circle.fill")
                                        .resizable()
                                        .frame(width: 100, height: 100)
                                        .foregroundColor(.red)
                                        .transition(.opacity)
                                }
                            }
                        }
                        .padding()
                    } else {
                        VStack {
                            Text("No more users")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                                .padding()

                            NavigationLink(destination: QuestionsView()) {
                                Text("Answer Questions")
                                    .foregroundColor(.white)
                                    .font(.custom("AvenirNext-Bold", size: 18))
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
            }
        }
    }

    private func likeAction() {
        interactionResult = .liked
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            interactionResult = nil
            currentIndex += 1
        }
    }

    private func dislikeAction() {
        interactionResult = .passed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            interactionResult = nil
            currentIndex += 1
        }
    }
}

// Subview for User Cards
struct UserCardView: View {
    var user: UserProfile

    var body: some View {
        VStack(spacing: 0) {
            Image(user.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.5)
                .clipped()
                .cornerRadius(20)
                .shadow(radius: 10)
                .overlay(
                    VStack {
                        Spacer()
                        HStack {
                            Text("\(user.name), \(user.rank)")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding([.leading, .bottom], 10)
                                .shadow(radius: 5)
                            Spacer()
                        }
                    }
                )
                .padding(.bottom, 5)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Age: \(user.age)")
                    Spacer()
                    Text("Server: \(user.server)")
                }
                .foregroundColor(.white)
                .font(.subheadline)
                .padding(.horizontal)

                HStack {
                    Text("Best Clip: \(user.bestClip)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal)
            }
            .frame(width: UIScreen.main.bounds.width * 0.85)
            .padding()
            .background(Color(.systemGray6).opacity(0.8))
            .cornerRadius(20)
            .shadow(radius: 5)
            .padding(.top, 5)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.9))
                .shadow(radius: 5)
        )
        .padding()
    }
}

// Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.dark) // Assuming dark mode preference
    }
}
