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
    var recipientUserID: String  // Add recipientUserID

    @State private var isInChatView: Bool = false // State to track if user is in chat view
    @State private var unreadMessageCount: Int = 0 // Add this state to track unread messages

    init(matchID: String, recipientName: String, recipientUserID: String) {
        self.matchID = matchID
        self.recipientName = recipientName
        self.recipientUserID = recipientUserID // Initialize recipientUserID
    }

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            // Pass recipientUserID to ChatView
            ChatView(matchID: matchID, recipientName: recipientName, recipientUserID: recipientUserID, isInChatView: $isInChatView, unreadMessageCount: $unreadMessageCount)
        }
        .onAppear {
            isInChatView = true // Set this to true when DM view appears
        }
        .onDisappear {
            isInChatView = false // Set this to false when DM view disappears
        }
    }
}
