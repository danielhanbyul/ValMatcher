//
//  Chat.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/23/24.
//

import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth

struct Chat: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var hasUnreadMessages: Bool?
    var recipientName: String?
    var timestamp: Timestamp?
    var lastMessageTimestamp: Timestamp?  // Add this to track the latest message timestamp
    var user1: String?
    var user1Image: String?
    var user1Name: String?
    var user2: String?
    var user2Image: String?
    var user2Name: String?
    var unreadMessages: [String: Int]?
    var lastMessageSenderID: String?
}


extension Chat {
    // Conform to Hashable by implementing the hash function
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // Implement Equatable to check for equality based on the unique identifier
    static func == (lhs: Chat, rhs: Chat) -> Bool {
        return lhs.id == rhs.id
    }
}


struct Message: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var senderID: String
    var content: String
    var timestamp: Timestamp
    var isRead: Bool = false
    var imageURL: String? = nil  // Support for images in messages
    var linkURL: String? = nil   // Optional support for links in messages

    var isCurrentUser: Bool {
        return senderID == Auth.auth().currentUser?.uid
    }

    // Implement Equatable based on the unique identifier
    static func == (lhs: Message, rhs: Message) -> Bool {
        return lhs.id == rhs.id
    }
}
