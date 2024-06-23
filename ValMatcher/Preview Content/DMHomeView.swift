//
//  DMHomeView.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/12/24.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift

struct DMHomeView: View {
    @StateObject private var firestoreManager = FirestoreManager()
    @State private var navigateToChat = false
    @State private var newMatchID: String?

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all)

                VStack {
                    Text("Direct Messages")
                        .font(.custom("AvenirNext-Bold", size: 28))
                        .foregroundColor(.white)
                        .padding(.top, 50)
                        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)

                    ScrollView {
                        ForEach(firestoreManager.chats) { chat in
                            NavigationLink(destination: DM(matchID: chat.id ?? "")) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Chat with \(chat.user2)")
                                            .font(.custom("AvenirNext-Bold", size: 18))
                                            .foregroundColor(.white)
                                        Text("Last message at \(chat.timestamp.dateValue(), formatter: dateFormatter)")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    Spacer()
                                }
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(12)
                                .padding(.horizontal)
                                .padding(.vertical, 5)
                                .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)
                            }
                        }
                    }
                    .padding(.top, 10)
                }
                
                if navigateToChat, let newMatchID = newMatchID {
                    NavigationLink(destination: DM(matchID: newMatchID), isActive: $navigateToChat) {
                        EmptyView()
                    }
                }
            }
            .onAppear {
                if !isPreview() {
                    if let currentUserID = Auth.auth().currentUser?.uid {
                        firestoreManager.loadChats(forUserID: currentUserID)
                    }
                } else {
                    // Load mock data for preview
                    self.firestoreManager.chats = [
                        Chat(id: "1", user1: "user1", user2: "user2", timestamp: Timestamp(date: Date())),
                        Chat(id: "2", user1: "user1", user2: "user3", timestamp: Timestamp(date: Date().addingTimeInterval(-86400)))
                    ]
                }
            }
        }
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

// Preview for DMHomeView
struct DMHomeView_Previews: PreviewProvider {
    static var previews: some View {
        DMHomeView()
            .environmentObject(FirestoreManager())
    }
}
