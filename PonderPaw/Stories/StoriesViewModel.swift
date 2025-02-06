//
//  StoriesViewModel.swift
//  PonderPaw
//
//  Created by Homer Quan on 2/6/25.
//

import Foundation

/// ViewModel for loading stories from Firestore for a given user.
class StoriesViewModel: ObservableObject {
    @Published var stories: [Story] = []
    
    // Use the shared FirebaseManager for database access.
    private let db = FirebaseManager.shared.db
    
    // The userId for which to load stories.
    let userId: String
    
    init(userId: String) {
        self.userId = userId
        loadStories()
    }
    
    /// Loads stories from Firestore where the document's `userId` matches the provided userId.
    func loadStories() {
        db.collection("stories")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching stories: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No stories found.")
                    return
                }
                
                let stories = documents.compactMap { doc -> Story? in
                    let data = doc.data()
                    // Use the provided "id" field if available; otherwise, use the document ID.
                    let id = data["id"] as? String ?? doc.documentID
                    
                    // Convert the "url" field to a URL.
                    var firebaseLink: URL? = nil
                    if let urlString = data["url"] as? String {
                        firebaseLink = URL(string: urlString)
                    }
                    
                    return Story(id: id, url: firebaseLink)
                }
                
                DispatchQueue.main.async {
                    self?.stories = stories
                }
            }
    }
}
