//
//  ChatView.swift
//  ValMatcher
//
//  Created by Daniel Han on 7/22/24.
//
import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    var matchID: String
    var recipientName: String
    @Binding var isInChatView: Bool
    @Binding var unreadMessageCount: Int

    @StateObject private var viewModel: ChatViewModel

    // New flag for listener removal control
    @State private var shouldRemoveListener = false

    init(matchID: String, recipientName: String, isInChatView: Binding<Bool>, unreadMessageCount: Binding<Int>) {
        self.matchID = matchID
        self.recipientName = recipientName
        self._isInChatView = isInChatView
        self._unreadMessageCount = unreadMessageCount
        _viewModel = StateObject(wrappedValue: ChatViewModel(matchID: matchID))
    }

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack {
                        ForEach(viewModel.messages) { message in
                            VStack {
                                if viewModel.shouldShowDate(for: message) {
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
                .onChange(of: viewModel.messages) { _ in
                    if viewModel.scrollToBottom {
                        DispatchQueue.main.async {
                            proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                        }
                    }
                }
            }

            HStack {
                TextField("Enter message", text: $viewModel.newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .frame(height: 40)

                Button(action: viewModel.sendMessage) {
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
        .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.15), Color(red: 0.21, green: 0.29, blue: 0.40)]), startPoint: .top, endPoint: .bottom))
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(recipientName)
        .onAppear {
            print("DEBUG: onAppear - Entering ChatView for matchID: \(matchID)")
            print("DEBUG: Current unreadMessageCount before entering: \(unreadMessageCount)")
            appState.isInChatView = true
            appState.currentChatID = matchID
            isInChatView = true
            viewModel.isInChatView = true
            
            // Debugging when messages are marked as read
            print("DEBUG: Marking all messages as read for matchID: \(matchID)")
            viewModel.markAllMessagesAsRead()
            shouldRemoveListener = false
        }

        .onDisappear {
            print("DEBUG: onDisappear - Triggered for matchID: \(matchID)")
            if !isInChatView {
                // Prevent unnecessary clean-up if still in ChatView
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if !isInChatView {
                        print("DEBUG: Cleaning up and removing listener for matchID: \(matchID)")
                        appState.removeChatListener(for: matchID)
                        isInChatView = false
                    } else {
                        print("DEBUG: Still in ChatView, listener not removed for matchID: \(matchID)")
                    }
                }
            }
        }




    }

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
                            viewModel.isFullScreenImagePresented = IdentifiableImageURL(url: imageURL)
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
                        viewModel.copiedText = message.content
                        viewModel.showAlert = true
                    }
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = message.content
                            viewModel.copiedText = message.content
                            viewModel.showAlert = true
                        }) {
                            Text("Copy")
                            Image(systemName: "doc.on.doc")
                        }
                    }
            }
        }
    }
}

// ViewModel for ChatView
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var newMessage: String = ""
    @Published var isFullScreenImagePresented: IdentifiableImageURL?
    @Published var showAlert = false
    @Published var copiedText = ""
    @Published var scrollToBottom: Bool = true

    private var messagesListener: ListenerRegistration?
    private var matchID: String
    private var currentUserID: String?
    var isInChatView: Bool = false
    private var seenMessageIDs: Set<String> = []

    init(matchID: String) {
        self.matchID = matchID
        self.currentUserID = Auth.auth().currentUser?.uid
        setupChatListener()
    }

    deinit {
        removeMessagesListener()
    }

    func sendMessage() {
        guard let currentUserID = Auth.auth().currentUser?.uid, !newMessage.isEmpty else { return }

        let messageToSend = newMessage
        self.newMessage = "" // Clear the input field immediately

        let db = Firestore.firestore()
        let messageData: [String: Any] = [
            "senderID": currentUserID,
            "content": messageToSend,
            "timestamp": Timestamp(),
            "isRead": false
        ]

        // Add the message to Firestore
        db.collection("matches").document(self.matchID).collection("messages").addDocument(data: messageData) { [weak self] error in
            if let error = error {
                print("Error sending message: \(error.localizedDescription)")
                return
            }

            // Update the chat timestamp
            db.collection("matches").document(self?.matchID ?? "").updateData(["lastMessageTimestamp": Timestamp()]) { error in
                if let error = error {
                    print("Error updating chat timestamp: \(error.localizedDescription)")
                }
            }
        }
    }


    private func setupChatListener() {
        print("DEBUG: Setting up Firebase chat listener for matchID: \(matchID)")
        
        let db = Firestore.firestore()
        messagesListener = db.collection("matches").document(self.matchID).collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener(includeMetadataChanges: false) { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("ERROR: Firebase listener encountered error: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("DEBUG: No messages found for matchID: \(self.matchID)")
                    return
                }
                
                for diff in snapshot.documentChanges {
                    switch diff.type {
                    case .added:
                        if let message = try? diff.document.data(as: Message.self) {
                            print("DEBUG: New message added: \(message.content) for matchID: \(self.matchID)")
                            if !self.seenMessageIDs.contains(message.id ?? "") {
                                self.messages.append(message)
                                self.seenMessageIDs.insert(message.id ?? "")
                                if !message.isCurrentUser && self.isInChatView {
                                    print("DEBUG: Marking message as read: \(message.id ?? "")")
                                    self.markMessageAsRead(messageID: message.id ?? "")
                                }
                                self.scrollToBottom = true
                            }
                        }
                    case .modified:
                        if let message = try? diff.document.data(as: Message.self),
                           let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                            print("DEBUG: Message modified: \(message.content) for matchID: \(self.matchID)")
                            self.messages[index] = message
                        }
                    case .removed:
                        if let index = self.messages.firstIndex(where: { $0.id == diff.document.documentID }) {
                            print("DEBUG: Message removed: \(self.messages[index].content) for matchID: \(self.matchID)")
                            self.messages.remove(at: index)
                        }
                    }
                }
            }
    }




    private func removeMessagesListener() {
        messagesListener?.remove()
        messagesListener = nil
    }

    private func markMessageAsRead(messageID: String) {
        let db = Firestore.firestore()
        print("DEBUG: Marking message as read in Firestore for messageID: \(messageID), matchID: \(matchID)")
        db.collection("matches").document(matchID).collection("messages").document(messageID).updateData(["isRead": true]) { error in
            if let error = error {
                print("ERROR: Failed to mark message as read: \(error.localizedDescription)")
            } else {
                print("DEBUG: Successfully marked message as read: \(messageID)")
            }
        }
    }

    func markAllMessagesAsRead() {
        guard let currentUserID = currentUserID else { return }
        let db = Firestore.firestore()
        let messagesRef = db.collection("matches").document(matchID).collection("messages")
        messagesRef.whereField("senderID", isNotEqualTo: currentUserID)
            .whereField("isRead", isEqualTo: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching unread messages: \(error.localizedDescription)")
                    return
                }

                let batch = db.batch()
                snapshot?.documents.forEach { document in
                    let messageRef = document.reference
                    batch.updateData(["isRead": true], forDocument: messageRef)
                }
                batch.commit { error in
                    if let error = error {
                        print("Error committing batch to mark messages as read: \(error.localizedDescription)")
                    }
                }
            }
    }

    func shouldShowDate(for message: Message) -> Bool {
        guard let index = messages.firstIndex(of: message) else { return false }
        if index == 0 { return true }
        let previousMessage = messages[index - 1]
        let calendar = Calendar.current
        return !calendar.isDate(message.timestamp.dateValue(), inSameDayAs: previousMessage.timestamp.dateValue())
    }
}


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

struct IdentifiableImageURL: Identifiable {
    var id: String { url }
    var url: String
}
