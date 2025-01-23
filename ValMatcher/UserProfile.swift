//
//  UserProfile.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/15/24.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct UserProfile: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String
    var rank: String?
    var imageName: String?
    var age: Int
    var server: String?
    var answers: [String: String]
    var hasAnsweredQuestions: Bool
    var mediaItems: [MediaItem]?
    var createdAt: Timestamp?
    var hasSeenTutorial: Bool
    var profileUpdated: Bool?

    init(id: String? = nil, name: String, rank: String, imageName: String, age: Int, server: String, answers: [String: String], hasAnsweredQuestions: Bool, mediaItems: [MediaItem]? = nil, createdAt: Timestamp? = nil, hasSeenTutorial: Bool = false, profileUpdated: Bool = false) {
        self.id = id
        self.name = name
        self.rank = rank
        self.imageName = imageName
        self.age = age
        self.server = server
        self.answers = answers
        self.hasAnsweredQuestions = hasAnsweredQuestions
        self.mediaItems = mediaItems ?? [] // Initialize with an empty array if `mediaItems` is nil
        self.createdAt = createdAt ?? Timestamp() // Set createdAt to current timestamp if nil
        self.hasSeenTutorial = hasSeenTutorial // Default to `false` if not provided
        self.profileUpdated = profileUpdated // Default to `false` if not provided
    }
}

extension UserProfile {
    mutating func merge(with updatedUser: UserProfile) {
        self.name = updatedUser.name.isEmpty ? self.name : updatedUser.name
        self.rank = updatedUser.rank ?? self.rank
        self.imageName = updatedUser.imageName ?? self.imageName
        self.age = updatedUser.age > 0 ? updatedUser.age : self.age
        self.server = updatedUser.server ?? self.server
        self.answers = updatedUser.answers.isEmpty ? self.answers : updatedUser.answers
        self.hasAnsweredQuestions = updatedUser.hasAnsweredQuestions
        self.mediaItems = updatedUser.mediaItems ?? self.mediaItems
        self.hasSeenTutorial = updatedUser.hasSeenTutorial
        self.profileUpdated = updatedUser.profileUpdated ?? self.profileUpdated
        self.createdAt = updatedUser.createdAt ?? self.createdAt
    }
}
