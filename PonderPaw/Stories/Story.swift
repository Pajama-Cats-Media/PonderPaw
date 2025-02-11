//
//  Story.swift
//  PonderPaw
//
//  Created by Homer Quan on 2/6/25.
//

import Foundation

/// A simple Story model.
struct Story: Identifiable, Hashable {
    // Use the story's "id" field from Firestore, or fallback to the document ID.
    let id: String
    let doc_title: String
    let doc_summary: String
    let url: URL?
    
    // You can add other properties such as `createdAt`, `type`, etc.
}
