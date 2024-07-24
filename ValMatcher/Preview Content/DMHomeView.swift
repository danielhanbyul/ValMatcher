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
    @State private var matches = [Chat]() // Use Chat model for matches
    @State private var currentUserID = Auth.auth().currentUser?.uid
    @State private var isEditing = false
    @State private var selectedMatches = Set<String>()
    @Binding var totalUnreadMessages: Int // Binding to track total unread messages

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                ScrollView {
                    ForEach(matches) { match in
                        matchRow(match: match)
                    }
                }
                .padding(.top, 10)
                
                if isEditing && !selectedMatches.isEmpty {
                    Button(action: deleteSelectedMatches) {
                        Text("Delete Selected")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                    .padding()
                }
            }
        }
        .navigationBarTitle("Messages", displayMode: .inline)
        .navigationBarItems(trailing: Button(action: { isEditing.toggle() }) {
            Text(isEditing ? "Done" : "Edit")
                .foregroundColor(.white)
        })
        .onAppear {
            loadMatches()
        }
    }

    @ViewBuilder
    private func matchRow(match: Chat) -> some View {
        HStack {
            if isEditing {
                Button(action: {
                    if selectedMatches.contains(match.id ?? "") {
                        selectedMatches.remove(match.id ?? "")
                    } else {
                        selectedMatches.insert(match.id ?? "")
                    }
                }) {
                    Image(systemName: selectedMatches.contains(match.id ?? "") ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(selectedMatches.contains(match.id ?? "") ? .blue : .white)
                        .padding()
                }
            }

            NavigationLink(destination: ChatView(matchID: match.id ?? "", recipientName: match.user1 == currentUserID ? match.user2Name ?? "Unknown User" : match.user1Name ?? "Unknown User")) {
                HStack {
                    if let currentUserID = currentUserID {
                        userImageView(currentUserID: currentUserID, match: match)
                    }

                    VStack(alignment: .leading) {
                        if let currentUserID = currentUserID {
                            Text(currentUserID == match.user1 ? (match.user2Name ?? "Unknown User") : (match.user1Name ?? "Unknown User"))
                                .font(.custom("AvenirNext-Bold", size: 18))
                                .foregroundColor(.white)
                        }
                        if match.hasUnreadMessages ?? false {
                            Text("Unread messages")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.top, 2)
                        }
                    }
                    .padding()
                    Spacer()

                    if match.hasUnreadMessages ?? false {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                    }
                }
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.vertical, 5)
                .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)
            }
        }
    }

    @ViewBuilder
    private func userImageView(currentUserID: String, match: Chat) -> some View {
        let currentUserImage = (currentUserID == match.user1 ? match.user2Image : match.user1Image) ?? "https://example.com/default-image.jpg"
        if let url = URL(string: currentUserImage) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 50, height: 50)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                case .failure:
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 50, height: 50)
        }
    }

    func loadMatches() {
        guard let currentUserID = currentUserID else {
            print("Error: currentUserID is nil")
            return
        }

        let db = Firestore.firestore()

        db.collection("matches")
            .whereField("user1", isEqualTo: currentUserID)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error loading matches for user1: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("No documents for user1")
                    return
                }

                let newMatches = documents.compactMap { document -> Chat? in
                    print("Document data: \(document.data())")
                    do {
                        let match = try document.data(as: Chat.self)
                        print("Fetched match for user1: \(String(describing: match))")
                        return match
                    } catch {
                        print("Error decoding match for user1: \(error.localizedDescription)")
                        return nil
                    }
                }
                
                self.matches = newMatches
                self.updateUnreadMessagesCount()
                print("Loaded matches for user1: \(newMatches)")
            }

        db.collection("matches")
            .whereField("user2", isEqualTo: currentUserID)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error loading matches for user2: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("No documents for user2")
                    return
                }

                let moreMatches = documents.compactMap { document -> Chat? in
                    print("Document data: \(document.data())")
                    do {
                        let match = try document.data(as: Chat.self)
                        print("Fetched match for user2: \(String(describing: match))")
                        return match
                    } catch {
                        print("Error decoding match for user2: \(error.localizedDescription)")
                        return nil
                    }
                }
                
                self.matches.append(contentsOf: moreMatches)
                self.matches = Array(Set(self.matches))
                self.updateUnreadMessagesCount()
                print("Loaded matches for user2: \(moreMatches)")
            }
    }

    func deleteSelectedMatches() {
        for matchID in selectedMatches {
            if let index = matches.firstIndex(where: { $0.id == matchID }) {
                let match = matches[index]
                deleteMatch(match)
                matches.remove(at: index)
            }
        }
        selectedMatches.removeAll()
    }

    func deleteMatch(_ match: Chat) {
        guard let matchID = match.id else {
            print("Match ID is missing")
            return
        }

        let db = Firestore.firestore()
        db.collection("matches").document(matchID).delete { error in
            if let error = error {
                print("Error deleting match: \(error.localizedDescription)")
            } else {
                print("Match deleted successfully")
            }
        }
    }

    private func updateUnreadMessagesCount() {
        totalUnreadMessages = 0
        
        for match in matches {
            guard let matchID = match.id else { continue }
            let db = Firestore.firestore()
            db.collection("matches").document(matchID).collection("messages")
                .whereField("isRead", isEqualTo: false)
                .whereField("senderID", isNotEqualTo: currentUserID ?? "")
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("Error fetching unread messages: \(error.localizedDescription)")
                        return
                    }
                    
                    let unreadCount = snapshot?.documents.count ?? 0
                    totalUnreadMessages += unreadCount
                }
        }
    }
}

let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

struct DMHomeView_Previews: PreviewProvider {
    static var previews: some View {
        DMHomeView(totalUnreadMessages: .constant(0))
            .environment(\.colorScheme, .dark)
    }
}
