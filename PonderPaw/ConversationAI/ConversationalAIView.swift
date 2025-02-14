//
//  ConversationalAIView.swift
//  PonderPaw
//
//  Created by Homer Quan on 1/15/25.
//

import SwiftUI

struct ConversationalAIView: View {
    @ObservedObject var viewModel : ConversationalAIViewModel
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    OrbView(mode: $viewModel.mode, audioLevel: $viewModel.audioLevel, status: $viewModel.status)
                        .padding(.bottom, 30)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}
