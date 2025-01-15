//
//  PlayerView.swift
//  PonderPaw
//
//  Created by Homer Quan on 1/9/25.
//
import SwiftUI

struct PlayerView: View {
    let url: URL
    @ObservedObject var viewModel: PlayerViewModel // Use @ObservedObject to allow shared viewModel

    var body: some View {
        ZStack {
            // Pass the accessible event controller
            WebContentView(url: url, eventController: viewModel.eventController)
            
            Button(action: {
                viewModel.turnPage()
            }) {
                Text("Click Anywhere")
                    .padding()
                    .background(Color.blue.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .opacity(1) // Makes it invisible
                    .accessibility(hidden: false)
            }
            .padding()
        }
    }
}
