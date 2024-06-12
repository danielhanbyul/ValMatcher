//
//  Message.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/12/24.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth

struct Message: Identifiable, Codable {
    @DocumentID var id: String?
    var senderID: String
    var content: String
    var timestamp: Timestamp

    var isCurrentUser: Bool {
        return Auth.auth().currentUser?.uid == senderID
    }
}
