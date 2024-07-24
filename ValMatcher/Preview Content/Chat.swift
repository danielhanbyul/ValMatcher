//
//  Chat.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/23/24.
//

import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth

struct Chat: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var user1: String
    var user2: String
    var user1Name: String?
    var user2Name: String?
    var user1Image: String?
    var user2Image: String?
    var recipientName: String?  // Add this line
    var timestamp: Timestamp

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}




import FirebaseFirestore
import FirebaseFirestoreSwift

struct Message: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var senderID: String
    var content: String
    var timestamp: Timestamp
    
    var isCurrentUser: Bool {
        return senderID == Auth.auth().currentUser?.uid
    }
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        return lhs.id == rhs.id
    }
}
