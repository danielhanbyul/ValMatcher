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
            
            Image(matchedUser.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .shadow(radius: 10)

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
        MatchNotificationView(matchedUser: UserProfile(name: "Alice", rank: "Bronze 1", imageName: "alice", age: "21", server: "NA", bestClip: "clip1", answers: [:], hasAnsweredQuestions: true))
            .preferredColorScheme(.dark)
    }
}
