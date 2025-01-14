import SwiftUI

struct ContentView: View {
    @State private var localServerURL: URL? = nil
    @State private var isServerStarting = true
    @StateObject private var subtitleViewModel = SubtitleViewModel(model: SubtitleModel(
        characters: ["O", "n", "c", "e", " ", "u", "p", "o", "n"],
        timings:    [0.0, 0.07, 0.174, 0.244, 0.383, 0.43, 0.522, 0.592, 0.68]
    ))
    
    private let server = LocalHTTPServer()
    private let webEventController = WebEventController() // Shared event controller
    
    var body: some View {
        ZStack {
            if isServerStarting {
                Text("Starting server...")
            } else if let url = localServerURL {
                PlayerView(url: url)
                    .navigationBarTitle("DEMO", displayMode: .inline)
                
                SubtitleView(viewModel: subtitleViewModel)
                    .frame(height: 100)
                    .padding()
                
            } else {
                Text("Failed to start the server.")
            }
            
            VStack {
                ConversationalAIView() // Main content is displayed here
            }
        }
        .onAppear {
            
            startLocalServer { success in
                if success, let jsonManifest = loadJsonManifest() {
                    let coPilot = CoPilot()
                    coPilot.loadJson(jsonManifest: jsonManifest) // Create the observable chain
                    coPilot.startReading() // Subscribe to start the flow
                    subtitleViewModel.startPlayback()
                } else {
                    print("Failed to load JSON manifest.")
                }
            }
        }
        .onDisappear {
            subtitleViewModel.stopPlayback()
            stopLocalServer()
        }
        .statusBarHidden(true) // This hides the status bar
    }
    
    private func startLocalServer(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .background).async {
            guard let folderPath = Bundle.main.path(forResource: "book", ofType: nil) else {
                print("Failed to locate 'book' directory in the project.")
                DispatchQueue.main.async {
                    self.isServerStarting = false
                    completion(false)
                }
                return
            }
            
            if let urlString = server.startServer(folderPath: folderPath),
               let url = URL(string: urlString) {
                DispatchQueue.main.async {
                    self.localServerURL = url
                    self.isServerStarting = false
                    completion(true)
                }
            } else {
                print("Failed to start the local server.")
                DispatchQueue.main.async {
                    self.isServerStarting = false
                    completion(false)
                }
            }
        }
    }
    
    private func stopLocalServer() {
        server.stopServer()
    }
    
    private func loadJsonManifest() -> String? {
        guard let filePath = Bundle.main.path(forResource: "default", ofType: "json", inDirectory: "book/playbooks/en-US") else {
            print("Failed to locate 'default.json' in 'book/playbooks/en-US' directory.")
            return nil
        }
        
        do {
            let jsonData = try String(contentsOfFile: filePath, encoding: .utf8)
            return jsonData
        } catch {
            print("Failed to read JSON file: \(error.localizedDescription)")
            return nil
        }
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
