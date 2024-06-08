//
//  NetworkManager.swift
//  ValMatcher
//
//  Created by Daniel Han on 6/7/24.
//

import Foundation

enum NetworkError: Error, LocalizedError {
    case invalidPassword
    case customError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidPassword:
            return "Password must be at least 8 characters long."
        case .customError(let message):
            return message
        }
    }
}

class NetworkManager {
    static let shared = NetworkManager()
    private let baseURL = "http://localhost:3000/api"
    
    func loginUser(email: String, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Validate password length
        guard password.count >= 8 else {
            completion(.failure(NetworkError.invalidPassword))
            return
        }

        guard let url = URL(string: "\(baseURL)/login") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["email": email, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: .fragmentsAllowed)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let token = json["token"] as? String {
                completion(.success(token))
            } else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
            }
        }.resume()
    }
    
    func registerUser(userName: String, email: String, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Validate password length
        guard password.count >= 8 else {
            completion(.failure(NetworkError.invalidPassword))
            return
        }

        guard let url = URL(string: "\(baseURL)/register") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["userName": userName, "email": email, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: .fragmentsAllowed)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let token = json["token"] as? String {
                completion(.success(token))
            } else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
            }
        }.resume()
    }
}
