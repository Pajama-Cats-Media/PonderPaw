import SwiftUI
import RxSwift

struct StoryPlayView: View {
    // New parameter that identifies the story to display
    let storyID: String
    
    @State private var localServerURL: URL? = nil
    @State private var isServerStarting = true
    @StateObject private var subtitleViewModel = SubtitleViewModel(model: SubtitleModel(
        content: "",
        characters: [],
        timings: []
    ))
    @StateObject private var playerViewModel = PlayerViewModel() // Manage PlayerViewModel
    @StateObject private var conversationalAIViewModel = ConversationalAIViewModel()
    @State private var coPilotRef: CoPilot?    // Store CoPilot reference
    
    private let server = LocalHTTPServer()
    private let disposeBag = DisposeBag()
    
    var body: some View {
        ZStack {
            if isServerStarting {
                Text("Starting server for story: \(storyID)...")
            } else if let url = localServerURL {
                ZStack {
                    PlayerView(url: url, viewModel: playerViewModel)
                    
                    // Subtitle styled like a typical subtitle
                    VStack {
                        SubtitleView(viewModel: subtitleViewModel)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(height: 40)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(20)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .onChange(of: playerViewModel.isDOMReady) { noReady, ready in
                    if ready {
                        loadCopilot()
                    }
                }
            } else {
                Text("Failed to start the server for story: \(storyID).")
            }
            
            VStack {
                ConversationalAIView(viewModel: conversationalAIViewModel)
            }
        }
        .onAppear {
            initializeApplication()
        }
        .onDisappear {
            cleanupApplication()
        }
        .statusBarHidden(true) // Hides the status bar
    }
    
    private func initializeApplication() {
        startLocalServer { success in
            if success {
                log.info("Local server started successfully for story: \(storyID).")
            } else {
                log.error("Failed to start the local server for story: \(storyID).")
            }
        }
    }
    
    private func loadCopilot() {
        guard let jsonManifest = loadJsonManifest() else {
            print("Failed to load JSON manifest.")
            return
        }
        
        let coPilot = CoPilot(conversationalAIViewModel: conversationalAIViewModel)
        coPilotRef = coPilot
        coPilot.loadJson(jsonManifest: jsonManifest)
        // Handle subtitle events
        coPilot.subtitleEvent
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { subtitleEvent in
                handleSubtitleEvent(subtitleEvent)
            })
            .disposed(by: disposeBag)
        
        // Handle page completion events
        coPilot.pageCompletionEvent
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { pageNumber in
                handlePageCompletion(pageNumber)
            })
            .disposed(by: disposeBag)
        
        coPilot.startReading()
    }
    
    private func handleSubtitleEvent(_ subtitleEvent: SubtitleEvent) {
        let subtitle = subtitleEvent.subtitle ?? [:]
        let content = subtitleEvent.content
        
        let chars = subtitle["chars"] as? [String] ?? []
        let timings = subtitle["timing"] as? [Double] ?? []
        
        subtitleViewModel.updateSubtitles(content: content, characters: chars, timings: timings)
        
        if !chars.isEmpty && !timings.isEmpty {
            subtitleViewModel.startPlayback()
        }
    }
    
    /// the pageName is the next page number
    private func handlePageCompletion(_ pageNumber: Int) {
        print("Turn page here: \(pageNumber)")
        playerViewModel.gotoPage(number: pageNumber)
    }
    
    private func cleanupApplication() {
        coPilotRef?.stopReading()
        subtitleViewModel.stopPlayback()
        stopLocalServer()
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

struct StoryPlayView_Previews: PreviewProvider {
    static var previews: some View {
        // Provide a dummy storyID for preview purposes
        StoryPlayView(storyID: "previewID")
    }
}

// Custom UIHostingController to hide the status bar
class HostingController<Content>: UIHostingController<Content> where Content: View {
    override var prefersStatusBarHidden: Bool {
        true // Return true to hide the status bar
    }
}
