import SwiftUI
import RxSwift

struct ContentView: View {
    @State private var localServerURL: URL? = nil
    @State private var isServerStarting = true
    @StateObject private var subtitleViewModel = SubtitleViewModel(model: SubtitleModel(
        content: "",
        characters: [],
        timings:    []
    ))
    
    private let server = LocalHTTPServer()
    private let webEventController = WebEventController() // Shared event controller
    private let disposeBag = DisposeBag()
    
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
                    coPilot.subtitleEvent
                        .observe(on: MainScheduler.instance)
                        .subscribe(onNext: { subtitleEvent in
                            // Access `subtitle` and `content` directly from the `SubtitleEvent` struct
                            let subtitle = subtitleEvent.subtitle
                            let content = subtitleEvent.content
                            
                            if let chars = subtitle["chars"] as? [String],
                               let timings = subtitle["timing"] as? [Double] {
                                // Update subtitle view model with subtitle information
                                subtitleViewModel.updateSubtitles(content: content, characters: chars, timings: timings)
                                subtitleViewModel.startPlayback()
                            }
                        })
                        .disposed(by: disposeBag)
                    
                    coPilot.pageCompletionEvent
                        .observe(on: MainScheduler.instance) // Ensure events are observed on the main thread
                        .subscribe(onNext: { pageNumber in
                            print("Turn page here: \(pageNumber) ")
                            // Handle page completion logic here
                            // For example, update the UI or log progress
                        })
                        .disposed(by: disposeBag)
                    
                    coPilot.startReading() // Subscribe to start the flow
                   
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
