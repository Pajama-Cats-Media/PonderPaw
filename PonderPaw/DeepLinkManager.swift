//
//  DeepLinkManager.swift
//  PonderPaw
//
//  Created by Homer Quan on 3/2/25.
//

import Combine

class DeepLinkManager: ObservableObject {
    @Published var storyID: String? = nil
    static let shared = DeepLinkManager()
}
