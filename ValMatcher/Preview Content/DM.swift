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

    init(matchID: String) {
        self.matchID = matchID
    }

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            ChatView(matchID: matchID)
        }
    }
}

struct DM_Previews: PreviewProvider {
    static var previews: some View {
        DM(matchID: "sampleMatchID")
            .preferredColorScheme(.dark)
    }
}
