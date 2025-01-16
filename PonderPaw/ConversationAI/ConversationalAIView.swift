//
//  ConversationalAIView.swift
//  PonderPaw
//
//  Created by Homer Quan on 1/15/25.
//

import SwiftUI

struct ConversationalAIView: View {
    @StateObject private var viewModel = ConversationalAIViewModel()
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                VStack {
                    OrbView(mode: viewModel.mode, audioLevel: viewModel.audioLevel)
                        .padding(.top, 10)
                    
                    Spacer()
                    
// //Enable it for testing
//                    Button(action: { viewModel.beginConversation() }) {
//                        ZStack {
//                            Circle()
//                                .fill(viewModel.status == .connected ? Color.red : Color.black)
//                                .frame(width: 80, height: 80)
//                                .shadow(radius: 5)
//                            
//                            Image(systemName: viewModel.status == .connected ? "speaker.wave.2.fill" : "mic.fill")
//                                .font(.system(size: 32, weight: .bold))
//                                .foregroundColor(.white)
//                        }
//                    }
//                    .padding(.bottom, 40)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}
