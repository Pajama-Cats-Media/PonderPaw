//
//  FirebaseManager.swift
//  PonderPaw
//
//  Created by Homer Quan on 2/6/25.
//

import FirebaseFirestore

/// A shared Firebase manager that provides a singleton Firestore database instance.
class FirebaseManager {
    static let shared = FirebaseManager()
    let db: Firestore

    private init() {
        self.db = Firestore.firestore()
    }
}
