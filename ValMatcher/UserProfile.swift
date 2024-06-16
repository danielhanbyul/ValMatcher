//
//  UserProfile.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/15/24.
//

import SwiftUI
import Foundation

struct UserProfile: Identifiable, Codable {
    var id: String = UUID().uuidString
    var name: String
    var rank: String
    var imageName: String
    var age: String
    var server: String
    var bestClip: String
    var answers: [String: String] // Dictionary to store question text and corresponding answer
}
