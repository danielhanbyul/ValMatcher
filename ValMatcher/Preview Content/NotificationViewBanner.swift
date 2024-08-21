//
//  NotificationViewBanner.swift
//  ValMatcher
//
//  Created by Daniel Han on 8/21/24.
//

import SwiftUI

struct NotificationBannerView: View {
    let username: String
    let message: String
    @Binding var isVisible: Bool

    var body: some View {
        VStack {
            if isVisible {
                HStack {
                    VStack(alignment: .leading) {
                        Text(username)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
                .shadow(radius: 10)
                .transition(.move(edge: .top))
                .animation(.easeInOut)
            }
            Spacer()
        }
        .padding()
    }
}
