//
//  Chat.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/23/24.
//

import FirebaseFirestore
import FirebaseFirestoreSwift

struct Chat: Identifiable, Codable {
    @DocumentID var id: String?
    var user1: String
    var user2: String
    var timestamp: Timestamp
}
