//
//  MatchNotification.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/23/24.
//

import SwiftUI

struct MatchNotificationView: View {
    var matchedUser: UserProfile

    var body: some View {
        VStack(spacing: 20) {
            Text("You have matched with \(matchedUser.name)!")
                .font(.title)
                .foregroundColor(.white)
                .padding()

            if let imageName = matchedUser.imageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .shadow(radius: 10)
            } else {
                Image(systemName: "person.circle.fill") // Placeholder image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .shadow(radius: 10)
            }

            Button(action: {
                // Add action to dismiss notification
            }) {
                Text("OK")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .frame(width: 300, height: 300)
        .background(Color.black.opacity(0.8))
        .cornerRadius(20)
        .shadow(radius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white, lineWidth: 2)
        )
    }
}

struct MatchNotificationView_Previews: PreviewProvider {
    static var previews: some View {
        MatchNotificationView(matchedUser: UserProfile(
            name: "Alice",
            rank: "Bronze 1",
            imageName: "alice", // Make sure this matches an existing image in your assets
            age: 21,
            server: "NA",
            answers: [:],
            hasAnsweredQuestions: true,
            mediaItems: [] // Only provide `mediaItems` if that's the correct structure
        ))
        .preferredColorScheme(.dark)
    }
}
