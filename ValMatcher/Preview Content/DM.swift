//
//  DM.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/12/24.
//

import SwiftUI
import Firebase

struct DM: View {
    var matchID: String
    var recipientName: String
    @State private var isInChatView: Bool = false // State to track if user is in chat view
    @State private var unreadMessageCount: Int = 0 // Add this state to track unread messages

    init(matchID: String, recipientName: String) {
        self.matchID = matchID
        self.recipientName = recipientName
    }

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            // Pass unreadMessageCount to ChatView
            ChatView(matchID: matchID, recipientName: recipientName, isInChatView: $isInChatView, unreadMessageCount: $unreadMessageCount)
        }
        .onAppear {
            isInChatView = true // Set this to true when DM view appears
        }
        .onDisappear {
            isInChatView = false // Set this to false when DM view disappears
        }
    }
}

struct DM_Previews: PreviewProvider {
    static var previews: some View {
        DM(matchID: "sampleMatchID", recipientName: "Unknown User")
            .preferredColorScheme(.dark)
    }
}
