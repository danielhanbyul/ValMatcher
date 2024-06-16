//
//  QuestionModel.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/15/24.
//

import SwiftUI

// Model for questions
enum QuestionType {
    case text
    case multipleChoice(options: [String])
}

struct Question: Identifiable {
    var id = UUID()
    var text: String
    var type: QuestionType
    var answer: String?
}
