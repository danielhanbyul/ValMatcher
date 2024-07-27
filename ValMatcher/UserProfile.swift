//
//  UserProfile.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/15/24.
//
import Foundation
import FirebaseFirestoreSwift

struct MediaItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var imageURL: String? = nil
    var videoURL: String? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case imageURL
        case videoURL
    }

    init(id: UUID = UUID(), imageURL: String? = nil, videoURL: String? = nil) {
        self.id = id
        self.imageURL = imageURL
        self.videoURL = videoURL
    }
}

struct UserProfile: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String
    var rank: String
    var imageName: String
    var age: String
    var server: String
    var answers: [String: String]
    var hasAnsweredQuestions: Bool
    var additionalImages: [String?]
    var mediaItems: [MediaItem]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case rank
        case imageName
        case age
        case server
        case answers
        case hasAnsweredQuestions
        case additionalImages
        case mediaItems
    }

    init(
        id: String? = nil,
        name: String,
        rank: String,
        imageName: String,
        age: String,
        server: String,
        answers: [String: String],
        hasAnsweredQuestions: Bool,
        additionalImages: [String?] = [],
        mediaItems: [MediaItem] = []
    ) {
        self.id = id
        self.name = name
        self.rank = rank
        self.imageName = imageName
        self.age = age
        self.server = server
        self.answers = answers
        self.hasAnsweredQuestions = hasAnsweredQuestions
        self.additionalImages = additionalImages
        self.mediaItems = mediaItems
    }

    static func == (lhs: UserProfile, rhs: UserProfile) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.rank == rhs.rank &&
        lhs.imageName == rhs.imageName &&
        lhs.age == rhs.age &&
        lhs.server == rhs.server &&
        lhs.answers == rhs.answers &&
        lhs.hasAnsweredQuestions == rhs.hasAnsweredQuestions &&
        lhs.additionalImages == rhs.additionalImages &&
        lhs.mediaItems == rhs.mediaItems
    }
}
