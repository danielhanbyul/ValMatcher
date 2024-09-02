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
    var mediaItems: [MediaItem]?

    // This initializer ensures that all fields are set, even if `mediaItems` is missing.
    init(id: String? = nil, name: String, rank: String, imageName: String, age: String, server: String, answers: [String: String], hasAnsweredQuestions: Bool, mediaItems: [MediaItem]? = nil) {
        self.id = id
        self.name = name
        self.rank = rank
        self.imageName = imageName
        self.age = age
        self.server = server
        self.answers = answers
        self.hasAnsweredQuestions = hasAnsweredQuestions
        self.mediaItems = mediaItems ?? [] // Initialize with an empty array if `mediaItems` is nil
    }
}
