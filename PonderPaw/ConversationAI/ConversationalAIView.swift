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
                    OrbView(mode: $viewModel.mode, audioLevel: $viewModel.audioLevel, status: $viewModel.status)
                        .padding(.top, 30)
                    Spacer()
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}
