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
    var age: String
    var server: String?
    var answers: [String: String]
    var hasAnsweredQuestions: Bool
    var mediaItems: [MediaItem]?
    var createdAt: Timestamp?
    var hasSeenTutorial: Bool // New property to track tutorial status
    var profileUpdated: Bool // New property to track profile updates

    // Updated initializer with `profileUpdated` as an optional parameter
    init(id: String? = nil, name: String, rank: String, imageName: String, age: String, server: String, answers: [String: String], hasAnsweredQuestions: Bool, mediaItems: [MediaItem]? = nil, createdAt: Timestamp? = nil, hasSeenTutorial: Bool = false, profileUpdated: Bool = false) {
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
