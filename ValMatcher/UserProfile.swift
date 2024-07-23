//
//  UserProfile.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/15/24.
//

import Foundation
import FirebaseFirestoreSwift

struct UserProfile: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String
    var rank: String
    var imageName: String
    var age: String
    var server: String
    var answers: [String: String]
    var hasAnsweredQuestions: Bool
    var additionalImages: [String?] // Use optional strings for URLs
}
