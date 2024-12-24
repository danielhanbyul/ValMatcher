//
//  addnotifsSentTomatches.swift
//  ValMatcher
//
//  Created by Daniel Han on 12/23/24.
//

import Firebase
import FirebaseFirestore

func addNotificationsSentToMatches() {
    let db = Firestore.firestore()

    db.collection("matches").getDocuments { (snapshot, error) in
        guard let documents = snapshot?.documents, error == nil else {
            print("Error fetching match documents: \(error?.localizedDescription ?? "Unknown error")")
            return
        }

        for document in documents {
            let matchID = document.documentID
            var data = document.data()

            // Add notificationsSent field if it's missing
            if data["notificationsSent"] == nil {
                let user1 = data["user1"] as? String ?? ""
                let user2 = data["user2"] as? String ?? ""

                let notificationsSent = [
                    user1: false,
                    user2: false
                ]

                db.collection("matches").document(matchID).updateData([
                    "notificationsSent": notificationsSent
                ]) { error in
                    if let error = error {
                        print("Error updating match \(matchID): \(error.localizedDescription)")
                    } else {
                        print("Updated match \(matchID) with notificationsSent.")
                    }
                }
            }
        }
    }
}


