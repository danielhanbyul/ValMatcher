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
    var age: Int
    var imageName: String
}

// View
struct ContentView: View {
    @State private var users = [
        UserProfile(name: "Alice", age: 24, imageName: "alice"),
        UserProfile(name: "Bob", age: 26, imageName: "bob"),
        UserProfile(name: "Charlie", age: 23, imageName: "charlie")
    ]
    @State private var currentIndex = 0

    var body: some View {
        VStack {
            if currentIndex < users.count {
                UserCardView(user: users[currentIndex])
                    .padding()
            } else {
                Text("No more users")
                    .font(.largeTitle)
                    .padding()
            }
            Spacer()
            HStack {
                Button(action: {
                    dislikeAction()
                }) {
                    Image(systemName: "xmark.circle")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.red)
                        .padding()
                }
                Button(action: {
                    likeAction()
                }) {
                    Image(systemName: "heart.circle")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.green)
                        .padding()
                }
            }
        }
    }

    private func likeAction() {
        // Handle like action
        currentIndex += 1
    }

    private func dislikeAction() {
        // Handle dislike action
        currentIndex += 1
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
                .frame(width: 300, height: 400)
                .clipped()
                .cornerRadius(20)
            Text("\(user.name), \(user.age)")
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
