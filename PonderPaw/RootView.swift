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

    var body: some View {
        Group {
            if isLoggedIn {
                HomeView()
            } else {
                // Pass the binding so LoginView can update the state on a successful login.
                LoginView(isLoggedIn: $isLoggedIn)
            }
        }
        // Place the auth listener here rather than on the Scene.
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
