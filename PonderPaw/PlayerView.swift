//
//  PlayerView.swift
//  PonderPaw
//
//  Created by Homer Quan on 1/9/25.
//
import SwiftUI

struct PlayerView: View {
    let url: URL
    private let webEventController = WebEventController() // Shared event controller
    
    var body: some View {
        ZStack {
            // Underlying WebView
            WebContentView(url: url, eventController: webEventController)
            
            // Button overlay to send a throttled event
            Button(action: {
                let message  = #"""
{
  "topic": "next_page"
}
"""#
                webEventController.sendEvent(message) // Send event using the shared controller
            }) {
                Text("Click Anywhere")
                    .padding()
                    .background(Color.blue.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()
        }
    }
}
