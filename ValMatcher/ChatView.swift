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


private func getAccessToken(completion: @escaping (String?) -> Void) {
    // Use the production URL from your deployed Cloud Function.
    guard let url = URL(string: "https://getaccesstoken-oj54mc4frq-uc.a.run.app") else {
        print("Invalid URL")
        completion(nil)
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Error fetching access token: \(error.localizedDescription)")
            completion(nil)
            return
        }
        
        guard let data = data else {
            print("No data received when fetching access token")
            completion(nil)
            return
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let token = json["accessToken"] as? String {
                completion(token)
            } else {
                print("Could not parse access token from response")
                completion(nil)
            }
        } catch {
            print("Error parsing JSON for access token: \(error)")
            completion(nil)
        }
    }.resume()
}




struct ChatView: View {
    @EnvironmentObject var appState: AppState
    var matchID: String
    var recipientName: String
    var recipientUserID: String  // Make sure to include this property
    @Binding var isInChatView: Bool
    @Binding var unreadMessageCount: Int

    @StateObject private var viewModel: ChatViewModel

    init(matchID: String, recipientName: String, recipientUserID: String, isInChatView: Binding<Bool>, unreadMessageCount: Binding<Int>) {
        self.matchID = matchID
        self.recipientName = recipientName
        self.recipientUserID = recipientUserID
        self._isInChatView = isInChatView
        self._unreadMessageCount = unreadMessageCount
        _viewModel = StateObject(wrappedValue: ChatViewModel(matchID: matchID, recipientName: recipientName, recipientUserID: recipientUserID))
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
            print("DEBUG: Entering ChatView for matchID: \(matchID)")
            appState.isInChatView = true
            appState.currentChatID = matchID
            isInChatView = true
            viewModel.isInChatView = true
            viewModel.markAllMessagesAsRead()
        }
        .onDisappear {
            print("DEBUG: Exiting ChatView for matchID: \(matchID)")
            appState.isInChatView = false
            appState.currentChatID = nil

            // Notify DMHomeView to refresh data
            NotificationCenter.default.post(name: Notification.Name("RefreshChatList"), object: matchID)
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

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import FirebaseFirestoreSwift
import UserNotifications

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
    private var recipientName: String
    let recipientUserID: String  // This is the recipient’s user ID
    var isInChatView: Bool = false
    private var seenMessageIDs: Set<String> = []
    private var isListenerActive: Bool = false
    private var currentUserName: String?  // Added currentUserName property

    // Updated initializer with recipientUserID as a parameter
    init(matchID: String, recipientName: String, recipientUserID: String) {
        self.matchID = matchID
        self.recipientName = recipientName
        self.recipientUserID = recipientUserID  // Now assigning the parameter value
        self.currentUserID = Auth.auth().currentUser?.uid
        self.fetchCurrentUserName()
        self.setupChatListener()
    }

    deinit {
        removeMessagesListener()
    }

    // Function to fetch the current user's name
    private func fetchCurrentUserName() {
        guard let currentUserID = self.currentUserID else { return }
        let db = Firestore.firestore()
        db.collection("users").document(currentUserID).getDocument { (document, error) in
            if let document = document, document.exists {
                self.currentUserName = document.data()?["name"] as? String
            } else {
                print("Error fetching current user name: \(error?.localizedDescription ?? "Unknown error")")
                self.currentUserName = "Unknown"
            }
        }
    }

    func sendMessage() {
        guard let currentUserID = self.currentUserID, !newMessage.isEmpty else { return }

        let messageToSend = newMessage
        self.newMessage = "" // Clear the input field immediately

        let db = Firestore.firestore()
        let messageData: [String: Any] = [
            "senderID": currentUserID,
            "senderName": currentUserName ?? "Unknown",  // Include senderName
            "content": messageToSend,
            "timestamp": Timestamp(),
            "isRead": false
        ]

        db.collection("matches").document(self.matchID).collection("messages").addDocument(data: messageData) { [weak self] error in
            if let error = error {
                print("Error sending message: \(error.localizedDescription)")
                return
            }

            db.collection("matches").document(self?.matchID ?? "").updateData(["lastMessageTimestamp": Timestamp()]) { error in
                if let error = error {
                    print("Error updating chat timestamp: \(error.localizedDescription)")
                } else {
                    // Successfully sent message, now send push notification to recipient
                    self?.sendPushNotificationViaCloudFunction(toRecipient: self?.recipientUserID ?? "", message: messageToSend)
                }
            }
        }
    }

    private func sendPushNotificationViaCloudFunction(toRecipient recipientID: String, message: String) {
        let db = Firestore.firestore()

        // Fetch the recipient's FCM token from Firestore
        db.collection("users").document(recipientID).getDocument { document, error in
            if let document = document, document.exists {
                let recipientFCMToken = document.data()?["fcmToken"] as? String
                if let recipientFCMToken = recipientFCMToken {
                    // Use currentUserName to send in the notification
                    let senderName = self.currentUserName ?? "Someone"
                    self.sendFCMNotification(
                        to: recipientFCMToken,
                        title: "New message from \(senderName)",
                        body: message
                    )
                } else {
                    print("Error: Recipient FCM token not found")
                }
            } else {
                print("Error: Recipient document not found")
            }
        }
    }

    private func setupChatListener() {
        guard !isListenerActive else { return }
        isListenerActive = true

        let db = Firestore.firestore()
        messagesListener = db.collection("matches").document(self.matchID).collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener(includeMetadataChanges: false) { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("Error loading messages: \(error.localizedDescription)")
                    return
                }

                guard let snapshot = snapshot else {
                    print("No messages found")
                    return
                }

                DispatchQueue.main.async {
                    for diff in snapshot.documentChanges {
                        switch diff.type {
                        case .added:
                            if let message = try? diff.document.data(as: Message.self) {
                                if !self.seenMessageIDs.contains(message.id ?? "") {
                                    self.messages.append(message)
                                    self.seenMessageIDs.insert(message.id ?? "")
                                    if !message.isCurrentUser && self.isInChatView {
                                        self.markMessageAsRead(messageID: message.id ?? "")
                                    }
                                    self.scrollToBottom = true
                                }
                            }
                        case .modified:
                            if let message = try? diff.document.data(as: Message.self),
                               let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                                self.messages[index] = message
                            }
                        case .removed:
                            if let index = self.messages.firstIndex(where: { $0.id == diff.document.documentID }) {
                                self.messages.remove(at: index)
                            }
                        }
                    }
                }
            }
    }

    func removeMessagesListener() {
        guard !isInChatView else {
            print("DEBUG: Preventing listener removal while in ChatView.")
            return
        }
        messagesListener?.remove()
        messagesListener = nil
        isListenerActive = false
    }

    private func markMessageAsRead(messageID: String) {
        let db = Firestore.firestore()
        db.collection("matches").document(matchID).collection("messages").document(messageID).updateData(["isRead": true]) { error in
            if let error = error {
                print("Error marking message as read: \(error.localizedDescription)")
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

    private func sendFCMNotification(to fcmToken: String, title: String, body: String) {
        let url = URL(string: "https://fcm.googleapis.com/v1/projects/valdatingapp-33e2e/messages:send")!

        getAccessToken { accessToken in
            guard let accessToken = accessToken else {
                print("Error: Failed to get access token")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") // Corrected

            let payload: [String: Any] = [
                "message": [
                    "token": fcmToken,
                    "notification": [
                        "title": title,
                        "body": body
                    ],
                    "android": [
                        "notification": [
                            "sound": "default"
                        ]
                    ],
                    "apns": [
                        "payload": [
                            "aps": [
                                "sound": "default"
                            ]
                        ]
                    ]
                ]
            ]


            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
            } catch {
                print("Error serializing JSON: \(error)")
                return
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error sending FCM notification: \(error.localizedDescription)")
                    return
                }

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    print("Notification sent successfully")
                } else {
                    print("Failed to send notification: \(response.debugDescription)")
                    if let data = data {
                        print("Response Data: \(String(data: data, encoding: .utf8) ?? "No response body")")
                    }
                }
            }.resume()
        }
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
