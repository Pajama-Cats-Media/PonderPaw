import SwiftUI
import WebKit

struct WebContentView: UIViewRepresentable {
    let url: URL
    let eventController: WebEventController // Shared event controller

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator

        // Disable user interaction
        webView.isUserInteractionEnabled = false

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

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    // Coordinator for handling navigation events
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebContentView

        init(_ parent: WebContentView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Inject JavaScript to notify when the page is fully loaded
            let readyEventScript = """
            document.addEventListener('DOMContentLoaded', function() {
                window.postMessage(JSON.stringify({ event: 'ready' }));
            });
            """
            webView.evaluateJavaScript(readyEventScript) { result, error in
                if let error = error {
                    print("Failed to inject ready event script: \(error)")
                }
            }

            // Emit the ready event to the shared event controller
            parent.eventController.sendEvent("ready")
        }
    }
}
