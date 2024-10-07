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
    @State private var isInChatView = false // State to track if user is in ChatView

    init(matchID: String, recipientName: String) {
        self.matchID = matchID
        self.recipientName = recipientName
    }

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            // Pass isInChatView state to ChatView
            ChatView(matchID: matchID, recipientName: recipientName, isInChatView: $isInChatView)
                .onAppear {
                    isInChatView = true // Set isInChatView to true when this view appears
                }
                .onDisappear {
                    isInChatView = false // Reset isInChatView to false when this view disappears
                }
        }
    }
}

struct DM_Previews: PreviewProvider {
    static var previews: some View {
        DM(matchID: "sampleMatchID", recipientName: "Unknown User")
            .preferredColorScheme(.dark)
    }
}
