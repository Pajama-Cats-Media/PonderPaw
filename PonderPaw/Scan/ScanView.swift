//
//  ScanView.swift
//  PonderPaw
//
//  Created by Homer Quan on 3/10/25.
//

import SwiftUI

struct ScanView: View {
    @Environment(\.dismiss) private var dismiss  // To navigate back

    var body: some View {
        VStack(spacing: 20) {
            Text("📷 Scan View")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("This is a placeholder for the Scan feature.")
                .font(.headline)
                .foregroundColor(.gray)
            
            Button(action: {
                dismiss()  // Go back
            }) {
                Text("Return")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: 200)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}
