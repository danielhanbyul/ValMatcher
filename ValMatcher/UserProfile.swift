//
//  UserProfile.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/15/24.
//

import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

import Foundation

struct UserProfile: Identifiable, Codable {
    var id: String? = UUID().uuidString
    var name: String
    var rank: String
    var imageName: String
    var age: String
    var server: String
    var bestClip: String
    var answers: [String: String]
    var hasAnsweredQuestions: Bool = false
    var media: [String] = [] // Add this line
}
