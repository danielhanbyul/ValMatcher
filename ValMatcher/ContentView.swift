//
//  ContentView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/6/24.
//

import SwiftUI

// Model
struct UserProfile: Identifiable {
    var id = UUID()
    var name: String
    var rank: String
    var imageName: String
}

// View
struct ContentView: View {
    @State private var users = [
        UserProfile(name: "Alice", rank: "Bronze 1", imageName: "alice"),
        UserProfile(name: "Bob", rank: "Silver 2", imageName: "bob"),
        UserProfile(name: "Charlie", rank: "Gold 3", imageName: "charlie"),
        UserProfile(name: "David", rank: "Platinum 1", imageName: "david"),
        UserProfile(name: "Eva", rank: "Diamond 2", imageName: "eva"),
        UserProfile(name: "Frank", rank: "Ascendant 3", imageName: "frank"),
        UserProfile(name: "Grace", rank: "Immortal 1", imageName: "grace"),
        UserProfile(name: "Hannah", rank: "Bronze 3", imageName: "hannah"),
        UserProfile(name: "Ivy", rank: "Radiant", imageName: "ivy"),
        UserProfile(name: "Jack", rank: "Silver 1", imageName: "jack")
    ]
    @State private var currentIndex = 0
    @State private var offset = CGSize.zero
    @State private var interactionResult: InteractionResult? = nil

    enum InteractionResult {
        case liked
        case passed
    }

    var body: some View {
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
            } else {
                Spacer()
                Text("No more users")
                    .font(.largeTitle)
                    .padding()
                Spacer()
            }
        }
        .edgesIgnoringSafeArea(.all)
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
        VStack {
            Image(user.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * 0.8)
                .clipped()
                .cornerRadius(20)
            Text("\(user.name), \(user.rank)")
                .font(.title)
                .padding()
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 5)
    }
}

// Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
