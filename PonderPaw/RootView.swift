//
//  RootView.swift
//  PonderPaw
//
//  Created by Homer Quan on 2/5/25.
//

import SwiftUI
import FirebaseAuth

struct RootView: View {
    @State private var isLoggedIn = false
    @StateObject private var deepLinkManager = DeepLinkManager.shared

    var body: some View {
        Group {
            // Universal Link takes precedence if a storyID is found
            if let storyId = deepLinkManager.storyID, !storyId.isEmpty {
                StoryPlayView(storyID: storyId)
            } else if isLoggedIn {
                HomeView()
            } else {
                // Pass the binding so LoginView can update the state on a successful login.
                LoginView(isLoggedIn: $isLoggedIn)
            }
        }
        // Handle incoming Universal Links
        .onOpenURL { url in
            // Example URL: https://paperheart-203fc.web.app/story?storyId=123
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
               let queryItems = components.queryItems,
               let storyId = queryItems.first(where: { $0.name == "storyId" })?.value {
                deepLinkManager.storyID = storyId
            }
        }
        .onAppear {
            Auth.auth().addStateDidChangeListener { auth, user in
                isLoggedIn = (user != nil)
            }
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}

