//
//  WebContentView.swift
//  PonderPaw
//
//  Created by Homer Quan on 1/9/25.
//

import SwiftUI
import WebKit

struct WebContentView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()

        // Enable Safari Web Inspector
        #if DEBUG
        print("enable web inspector")
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        webView.isInspectable = true
        #endif

        // Disable user interaction
        webView.isUserInteractionEnabled = false

        // Load the URL
        let request = URLRequest(url: url)
        webView.load(request)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Update logic if needed
    }
}
