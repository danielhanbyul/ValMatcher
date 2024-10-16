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
            print("DEBUG: Entering ChatView for matchID: \(matchID), setting isInChatView to true")
            appState.isInChatView = true
            appState.currentChatID = matchID
            isInChatView = true
            viewModel.isInChatView = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("DEBUG: Marking all messages as read for matchID: \(matchID)")
                viewModel.markAllMessagesAsRead()
            }
        }
        .onDisappear {
            print("DEBUG: onDisappear triggered for matchID: \(matchID)")
            print("DEBUG: Current isInChatView state: \(isInChatView)")

            // Check if we're actually allowed to remove the listener (if the user is NOT in the chat anymore)
            if !isInChatView {
                print("DEBUG: User is not in chat, proceeding with listener removal for matchID: \(matchID)")
                DispatchQueue.main.async {
                    print("DEBUG: Exiting ChatView, removing listener for matchID: \(matchID)")
                    appState.isInChatView = false
                    appState.currentChatID = nil
                    viewModel.isInChatView = false
                    // Clean up listener
                    viewModel.removeMessagesListener()
                    print("DEBUG: Listener removed for matchID: \(matchID)")
                }
            } else {
                print("DEBUG: Preventing listener removal because user is still in chat for matchID: \(matchID)")
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


// ViewModel for ChatView with Debug Logging
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
        print("DEBUG: ChatViewModel deinitialized and listener removed for matchID: \(matchID)")
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

        print("DEBUG: Sending message: \(messageData)")

        db.collection("matches").document(self.matchID).collection("messages").addDocument(data: messageData) { [weak self] error in
            if let error = error {
                print("DEBUG: Error sending message: \(error.localizedDescription)")
                return
            }

            print("DEBUG: Message sent successfully for matchID: \(self?.matchID ?? "")")

            db.collection("matches").document(self?.matchID ?? "").updateData(["lastMessageTimestamp": Timestamp()]) { error in
                if let error = error {
                    print("DEBUG: Error updating chat timestamp: \(error.localizedDescription)")
                } else {
                    print("DEBUG: Chat timestamp updated for matchID: \(self?.matchID ?? "")")
                }
            }
        }
    }

    private func setupChatListener() {
        let db = Firestore.firestore()
        print("DEBUG: Setting up chat listener for matchID: \(self.matchID)")
        
        messagesListener = db.collection("matches").document(self.matchID).collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener(includeMetadataChanges: false) { [weak self] snapshot, error in
                guard let self = self else { return }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if let error = error {
                        print("DEBUG: Error loading messages: \(error.localizedDescription)")
                        return
                    }

                    guard let snapshot = snapshot else {
                        print("DEBUG: No messages found for matchID: \(self.matchID)")
                        return
                    }

                    print("DEBUG: Received snapshot update for matchID: \(self.matchID), message count: \(snapshot.documents.count)")

                    for diff in snapshot.documentChanges {
                        switch diff.type {
                        case .added:
                            if let message = try? diff.document.data(as: Message.self) {
                                print("DEBUG: New message added with ID: \(message.id ?? "N/A")")
                                if !self.seenMessageIDs.contains(message.id ?? "") {
                                    self.messages.append(message)
                                    self.seenMessageIDs.insert(message.id ?? "")
                                    if !message.isCurrentUser && self.isInChatView {
                                        print("DEBUG: Marking message as read for ID: \(message.id ?? "N/A")")
                                        self.markMessageAsRead(messageID: message.id ?? "")
                                    }
                                    self.scrollToBottom = true
                                }
                            }
                        case .modified:
                            if let message = try? diff.document.data(as: Message.self),
                               let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                                print("DEBUG: Message modified with ID: \(message.id ?? "N/A")")
                                self.messages[index] = message
                            }
                        case .removed:
                            if let index = self.messages.firstIndex(where: { $0.id == diff.document.documentID }) {
                                print("DEBUG: Message removed with ID: \(diff.document.documentID)")
                                self.messages.remove(at: index)
                            }
                        }
                    }
                }
            }
    }

    func removeMessagesListener() {
        messagesListener?.remove()
        messagesListener = nil
        print("DEBUG: Removed messages listener for matchID: \(matchID)")
    }

    private func markMessageAsRead(messageID: String) {
        let db = Firestore.firestore()
        db.collection("matches").document(matchID).collection("messages").document(messageID).updateData(["isRead": true]) { error in
            if let error = error {
                print("DEBUG: Error marking message as read: \(error.localizedDescription)")
            } else {
                print("DEBUG: Message marked as read for messageID: \(messageID)")
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
                    print("DEBUG: Error fetching unread messages: \(error.localizedDescription)")
                    return
                }

                let batch = db.batch()
                snapshot?.documents.forEach { document in
                    let messageRef = document.reference
                    batch.updateData(["isRead": true], forDocument: messageRef)
                    print("DEBUG: Marking message as read in batch for messageID: \(document.documentID)")
                }
                batch.commit { error in
                    if let error = error {
                        print("DEBUG: Error committing batch to mark messages as read: \(error.localizedDescription)")
                    } else {
                        print("DEBUG: All messages marked as read for matchID: \(self.matchID)")
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
