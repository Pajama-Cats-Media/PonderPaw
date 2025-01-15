import SwiftUI
import WebKit
import RxSwift

struct WebContentView: UIViewRepresentable {
    let url: URL
    let viewModel: WebContentViewModel

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator

        #if DEBUG
        print("Enable web inspector")
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        webView.isInspectable = true
        #endif

        // Load the initial URL
        let request = URLRequest(url: url)
        webView.load(request)

        // Subscribe to the ViewModel's throttled events
        context.coordinator.bindViewModel(to: webView, viewModel: viewModel)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Update logic if needed
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        private let disposeBag = DisposeBag()
        private let viewModel: WebContentViewModel

        init(viewModel: WebContentViewModel) {
            self.viewModel = viewModel
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let readyEventScript = """
            document.addEventListener('DOMContentLoaded', function() {
                window.postMessage(JSON.stringify({ event: 'ready' }));
            });
            """
            webView.evaluateJavaScript(readyEventScript) { result, error in
                if let error = error {
                    print("Failed to inject ready event script: \(error)")
                } else {
                    // Notify the ViewModel about the DOM ready event only after successful script injection
                    self.viewModel.notifyDOMReady()
                }
            }
        }

        /// Binds the ViewModel's event stream to the WKWebView
        func bindViewModel(to webView: WKWebView, viewModel: WebContentViewModel) {
            viewModel.throttledEvent
                .subscribe(onNext: { message in
                    let base64Message = message.data(using: .utf8)?.base64EncodedString() ?? ""
                    let jsCommand = "window.postMessage('\(base64Message)');"
                    webView.evaluateJavaScript(jsCommand) { result, error in
                        if let error = error {
                            print("JavaScript Error: \(error)")
                        }
                    }
                })
                .disposed(by: disposeBag)
        }
    }
}

