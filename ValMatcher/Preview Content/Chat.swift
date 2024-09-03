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
    @DocumentID var id: String?  // Optional Document ID
    var hasUnreadMessages: Bool?  // Optional field for unread messages
    var recipientName: String?    // Optional field for recipient's name
    var timestamp: Timestamp?     // Optional timestamp
    var user1: String?            // Optional user ID for user1
    var user1Image: String?       // Optional image URL for user1
    var user1Name: String?        // Optional name for user1
    var user2: String?            // Optional user ID for user2
    var user2Image: String?       // Optional image URL for user2
    var user2Name: String?        // Optional name for user2
    var unreadMessages: [String: Int]?  // Optional map for unread messages
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
