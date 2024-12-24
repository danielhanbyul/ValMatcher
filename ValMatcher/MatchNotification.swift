//
//  MatchNotification.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/23/24.
//

import SwiftUI
import Kingfisher

struct MatchNotificationView: View {
    let message: String
    let imageURL: URL?
    let dismissAction: () -> Void

    var body: some View {
        VStack(spacing: 15) {
            Text("It's a Match!")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top, 10)

            if let imageURL = imageURL {
                KFImage(imageURL)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 5)
            }

            Text(message)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)

            Button(action: dismissAction) {
                Text("OK")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(Color.black.opacity(0.85))
        .cornerRadius(15)
        .shadow(radius: 10)
        .frame(width: UIScreen.main.bounds.width * 0.85)
    }
}
