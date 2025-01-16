//
//  OrbView.swift
//  PonderPaw
//
//  Created by Homer Quan on 1/15/25.
//

import SwiftUI
import ElevenLabsSDK

struct OrbView: View {
    @Binding var mode: ElevenLabsSDK.Mode
    @Binding var audioLevel: Float
    @Binding var status: ElevenLabsSDK.Status
    
    private var iconName: String {
        switch mode {
        case .listening:
            return "waveform"
        case .speaking:
            return "speaker.wave.2.fill"
        }
    }
    
    private var scale: CGFloat {
        let calculatedScale = 0.9 + CGFloat(audioLevel * 3)
        return calculatedScale
    }
    
    var body: some View {
        Group {
            if status == .connected {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 48, height: 48)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .blur(radius: 0.5)
                        .scaleEffect(scale)
                        .animation(.spring(response: 0.1, dampingFraction: 0.8), value: scale)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.black)
                        .scaleEffect(scale)
                        .animation(.spring(response: 0.1, dampingFraction: 0.8), value: scale)
                }
            }
        }
    }
}
