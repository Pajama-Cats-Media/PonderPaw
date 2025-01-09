import SwiftUI
import WebKit

struct WebContentView: UIViewRepresentable {
    let url: URL
    let eventController: WebEventController // Shared event controller

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()

        // Enable Safari Web Inspector
        #if DEBUG
        print("enable web inspector")
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        webView.isInspectable = true
        #endif

        // Load the URL
        let request = URLRequest(url: url)
        webView.load(request)

        // Subscribe to throttled events to inject messages into WebView
        eventController.onEventReceived { message in
            let base64Message = message.data(using: .utf8)?.base64EncodedString() ?? ""
            let jsCommand = "window.postMessage('\(base64Message)');"
            webView.evaluateJavaScript(jsCommand) { result, error in
                if let error = error {
                    print("JavaScript Error: \(error)")
                }
            }
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Update logic if needed
    }

    func sendEventToWebView(_ message: String) {
        eventController.sendEvent(message)
    }
}
