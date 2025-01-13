import SwiftUI

struct ContentView: View {
    @State private var localServerURL: URL? = nil
    @State private var isServerStarting = true
    private let server = LocalHTTPServer()
    private let webEventController = WebEventController() // Shared event controller
    
    
    var body: some View {
        ZStack {
            if isServerStarting {
                Text("Starting server...")
            } else if let url = localServerURL {
                PlayerView(url: url)
                    .navigationBarTitle("DEMO", displayMode: .inline)
            } else {
                Text("Failed to start the server.")
            }
            
            VStack {
                ConversationalAIView() // Main content is displayed here
            }
        }
        .onAppear {
            startLocalServer()
            
            let jsonManifest = """
            {
              "pages": [
                {
                  "pageNumber": 1,
                  "actions": [
                    {"type": "read", "content": "Once upon a time...", "audio": "0dbdbb39-6ff6-55a2-a436-0da2d017c126.mp3"},
                    {"type": "suggestion", "content": "Think about the main character."}
                  ]
                },
                {
                  "pageNumber": 2,
                  "actions": [
                    {"type": "read", "content": "The cat jumped over the moon."},
                    {"type": "suggestion", "content": "Why do you think the cat jumped?"}
                  ]
                }
              ]
            }
            """

            let coPilot = CoPilot()
            coPilot.loadJson(jsonManifest: jsonManifest) // Create the observable chain
            coPilot.startReading() // Subscribe to start the flow
            
            
        }
        .onDisappear {
            stopLocalServer()
        }
        .statusBarHidden(true) // This hides the status bar
    }
    
    private func startLocalServer() {
        DispatchQueue.global(qos: .background).async {
            guard let folderPath = Bundle.main.path(forResource: "book", ofType: nil) else {
                print("Failed to locate 'book' directory in the project.")
                DispatchQueue.main.async {
                    self.isServerStarting = false
                }
                return
            }
            
            if let urlString = server.startServer(folderPath: folderPath),
               let url = URL(string: urlString) {
                DispatchQueue.main.async {
                    self.localServerURL = url
                    self.isServerStarting = false
                }
            } else {
                print("Failed to start the local server.")
                DispatchQueue.main.async {
                    self.isServerStarting = false
                }
            }
        }
    }
    
    private func stopLocalServer() {
        server.stopServer()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// Custom UIHostingController to hide the status bar
class HostingController<Content>: UIHostingController<Content> where Content: View {
    override var prefersStatusBarHidden: Bool {
        true // Return true to hide the status bar
    }
}
