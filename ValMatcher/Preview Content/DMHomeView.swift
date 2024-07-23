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
    @State private var chats = [Chat]()
    @State private var currentUserID = Auth.auth().currentUser?.uid
    @State private var isEditing = false
    @State private var selectedChats = Set<String>()

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            VStack {
                HStack {
                    Spacer()
                    Button(action: { isEditing.toggle() }) {
                        Text(isEditing ? "Done" : "Edit")
                            .foregroundColor(.white)
                            .padding()
                    }
                }

                ScrollView {
                    ForEach(chats) { chat in
                        HStack {
                            if isEditing {
                                Button(action: {
                                    if selectedChats.contains(chat.id ?? "") {
                                        selectedChats.remove(chat.id ?? "")
                                    } else {
                                        selectedChats.insert(chat.id ?? "")
                                    }
                                }) {
                                    Image(systemName: selectedChats.contains(chat.id ?? "") ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedChats.contains(chat.id ?? "") ? .blue : .white)
                                        .padding()
                                }
                            }

                            NavigationLink(destination: DM(matchID: chat.id ?? "")) {
                                HStack {
                                    if let currentUserID = currentUserID {
                                        let currentUserImage = (currentUserID == chat.user1 ? chat.user2Image : chat.user1Image) ?? "https://example.com/default-image.jpg"
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

                                    VStack(alignment: .leading) {
                                        if let currentUserID = currentUserID {
                                            Text(currentUserID == chat.user1 ? (chat.user2Name ?? "Unknown User") : (chat.user1Name ?? "Unknown User"))
                                                .font(.custom("AvenirNext-Bold", size: 18))
                                                .foregroundColor(.white)
                                        }
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
                }
                .padding(.top, 10)
                
                if isEditing && !selectedChats.isEmpty {
                    Button(action: deleteSelectedChats) {
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
        .onAppear {
            loadChats()
        }
    }

    func loadChats() {
        guard let currentUserID = currentUserID else {
            print("Error: currentUserID is nil")
            return
        }

        let db = Firestore.firestore()

        db.collection("matches")
            .whereField("user1", isEqualTo: currentUserID)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error loading chats for user1: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("No documents for user1")
                    return
                }

                let newChats = documents.compactMap { document -> Chat? in
                    print("Document data: \(document.data())")
                    do {
                        let chat = try document.data(as: Chat.self)
                        print("Fetched chat for user1: \(String(describing: chat))")
                        return chat
                    } catch {
                        print("Error decoding chat for user1: \(error.localizedDescription)")
                        return nil
                    }
                }
                
                self.chats = newChats // Overwrite the chats list to prevent duplicates
                print("Loaded chats for user1: \(newChats)")
            }

        db.collection("matches")
            .whereField("user2", isEqualTo: currentUserID)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error loading chats for user2: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("No documents for user2")
                    return
                }

                let moreChats = documents.compactMap { document -> Chat? in
                    print("Document data: \(document.data())")
                    do {
                        let chat = try document.data(as: Chat.self)
                        print("Fetched chat for user2: \(String(describing: chat))")
                        return chat
                    } catch {
                        print("Error decoding chat for user2: \(error.localizedDescription)")
                        return nil
                    }
                }
                
                self.chats.append(contentsOf: moreChats)
                self.chats = Array(Set(self.chats)) // Remove duplicates by converting to a Set and back to an Array
                print("Loaded chats for user2: \(moreChats)")
            }
    }

    func deleteSelectedChats() {
        for chatID in selectedChats {
            if let index = chats.firstIndex(where: { $0.id == chatID }) {
                let chat = chats[index]
                deleteChat(chat)
                chats.remove(at: index)
            }
        }
        selectedChats.removeAll()
    }

    func deleteChat(_ chat: Chat) {
        guard let chatID = chat.id else {
            print("Chat ID is missing")
            return
        }

        let db = Firestore.firestore()
        db.collection("matches").document(chatID).delete { error in
            if let error = error {
                print("Error deleting chat: \(error.localizedDescription)")
            } else {
                print("Chat deleted successfully")
            }
        }
    }

    private func isPreview() -> Bool {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()
