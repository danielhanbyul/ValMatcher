//
//  ChatView.swift
//  ValMatcher
//
//  Created by Daniel Han on 7/22/24.
//
import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth

struct ChatView: View {
    var matchID: String
    var recipientName: String
    @State private var messages: [Message] = []
    @State private var newMessage: String = ""
    @State private var currentUserID = Auth.auth().currentUser?.uid
    @State private var scrollToBottom: Bool = true
    @State private var messagesListener: ListenerRegistration?
    @State private var selectedImage: UIImage?
    @State private var isFullScreenImagePresented: IdentifiableImageURL?
    @State private var showAlert = false
    @State private var copiedText = ""
    @State private var lastMessageID: String?
    @State private var isInChatView = false // Added to track if the user is in ChatView

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack {
                        ForEach(messages) { message in
                            VStack {
                                if shouldShowDate(for: message) {
                                    Text("\(message.timestamp.dateValue(), formatter: dateOnlyFormatter)")
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                        .padding(.top, 10)
                                }

                                HStack {
                                    if message.isCurrentUser {
                                        Spacer()
                                        VStack(alignment: .trailing) {
                                            messageContent(for: message)
                                                .background(Color.blue)
                                                .cornerRadius(8)
                                                .foregroundColor(.white)
                                                .frame(maxWidth: 300, alignment: .trailing)
                                            Text("\(message.timestamp.dateValue(), formatter: timeFormatter)")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .padding(.top, 2)
                                        }
                                    } else {
                                        VStack(alignment: .leading) {
                                            messageContent(for: message)
                                                .background(Color.gray)
                                                .cornerRadius(8)
                                                .foregroundColor(.black)
                                                .frame(maxWidth: 300, alignment: .leading)
                                            Text("\(message.timestamp.dateValue(), formatter: timeFormatter)")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                                .padding(.top, 2)
                                        }
                                        Spacer()
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 5)
                                .id(message.id)
                            }
                        }
                    }
                }
                .onChange(of: messages) { _ in
                    if scrollToBottom {
                        DispatchQueue.main.async {
                            if let lastMessageID = messages.last?.id {
                                proxy.scrollTo(lastMessageID, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            // Input field and send button
            HStack {
                TextField("Enter message", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .frame(height: 40)

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .padding()
            }
            .padding()
        }
        .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15),
                                                              Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom))
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(recipientName)
        .onAppear {
            self.isInChatView = true // Mark as inside ChatView
            setupChatListener()
        }
        .onDisappear {
            self.isInChatView = false // Mark as outside ChatView
            removeMessagesListener()
        }
    }

    // View for message content (Text or Image)
    private func messageContent(for message: Message) -> some View {
        Group {
            if let imageURL = message.imageURL {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 150)
                        .cornerRadius(8)
                        .onTapGesture {
                            isFullScreenImagePresented = IdentifiableImageURL(url: imageURL)
                        }
                } placeholder: {
                    ProgressView()
                        .frame(width: 150, height: 150)
                }
            } else {
                Text(message.content)
                    .padding()
                    .onTapGesture(count: 2) {
                        UIPasteboard.general.string = message.content
                        copiedText = message.content
                        showAlert = true
                    }
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = message.content
                            copiedText = message.content
                            showAlert = true
                        }) {
                            Text("Copy")
                            Image(systemName: "doc.on.doc")
                        }
                    }
            }
        }
    }

    // Send a message
    private func sendMessage() {
        guard let currentUserID = currentUserID, !newMessage.isEmpty else { return }

        let db = Firestore.firestore()
        let messageData: [String: Any] = [
            "senderID": currentUserID,
            "content": newMessage,
            "timestamp": Timestamp(),
            "isRead": false
        ]

        // Add the message to Firestore
        db.collection("matches").document(matchID).collection("messages").addDocument(data: messageData) { error in
            if let error = error {
                print("Error sending message: \(error.localizedDescription)")
                return
            }

            // Update the chat timestamp to the most recent
            db.collection("matches").document(matchID).updateData(["lastMessageTimestamp": Timestamp()]) { error in
                if let error = error {
                    print("Error updating chat timestamp: \(error.localizedDescription)")
                } else {
                    self.newMessage = "" // Clear the input field after sending
                }
            }
        }
    }

    // Setup listener for incoming messages
    private func setupChatListener() {
        let db = Firestore.firestore()
        
        // Use the listener only when the user is not in the ChatView
        if !isInChatView {
            messagesListener = db.collection("matches").document(matchID).collection("messages")
                .order(by: "timestamp", descending: false)
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        print("Error loading messages: \(error.localizedDescription)")
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        print("No messages found")
                        return
                    }

                    // Check if new messages are different from current messages to prevent unnecessary refreshes
                    let newMessages = documents.compactMap { document in
                        try? document.data(as: Message.self)
                    }

                    if newMessages != self.messages {
                        self.messages = newMessages
                        DispatchQueue.main.async {
                            scrollToBottom = true
                        }
                    }
                }
        }
    }

    // Remove the listener when leaving the view
    private func removeMessagesListener() {
        messagesListener?.remove()
        messagesListener = nil
    }

    // Determine if the date header should be shown between messages
    private func shouldShowDate(for message: Message) -> Bool {
        guard let index = messages.firstIndex(of: message) else { return false }
        if index == 0 { return true }
        let previousMessage = messages[index - 1]
        let calendar = Calendar.current
        return !calendar.isDate(message.timestamp.dateValue(), inSameDayAs: previousMessage.timestamp.dateValue())
    }
}

// Date Formatters
let dateOnlyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .none
    return formatter
}()

let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
}()

// Struct to handle fullscreen images
struct IdentifiableImageURL: Identifiable {
    var id: String { url }
    var url: String
}
