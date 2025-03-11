//
//  StoryPlayView.swift
//  PonderPaw
//
//  Created by Homer Quan on 2/6/25.
//

import RxSwift
import SwiftUI

struct StoryPlayView: View {
    @Environment(\.dismiss) private var dismiss  // Inject dismiss environment

    // New parameter that identifies the story to display
    let storyID: String

    @State private var localServerURL: URL? = nil
    // New state property to hold the local folder URL for the story.
    @State private var storyFolderURL: URL? = nil
    @State private var isServerStarting = true
    @StateObject private var subtitleViewModel = SubtitleViewModel(
        model: SubtitleModel(
            content: "",
            characters: [],
            timings: []
        ))
    @StateObject private var playerViewModel = PlayerViewModel()  // Manage PlayerViewModel
    @StateObject private var conversationalAIViewModel =
        ConversationalAIViewModel()
    @State private var coPilotRef: CoPilot?  // Store CoPilot reference

    private let server = LocalHTTPServer()
    private let disposeBag = DisposeBag()

    var body: some View {
        ZStack {
            if isServerStarting {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)  // Increase the size of the spinner
                        .padding()
                }
            } else if let url = localServerURL {
                ZStack {
                    PlayerView(url: url, viewModel: playerViewModel)

                    // Subtitle styled like a typical subtitle
                    VStack {
                        SubtitleView(viewModel: subtitleViewModel)
                            .fixedSize(horizontal: true, vertical: false)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(20)
                            .foregroundColor(.white)
                    }
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .bottom
                    )
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
        .onChange(of: conversationalAIViewModel.subtitle) { newSubtitle in
            let event = SubtitleEvent(subtitle: [:], content: newSubtitle)
            handleSubtitleEvent(event)
        }
        .onAppear {
            initializeApplication()
        }
        .onDisappear {
            cleanupApplication()
        }
        .statusBarHidden(true)  // Hides the status bar
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.white) // Ensure white icon for visibility
                        .padding(8)
                        .background(Color.black) // Dark semi-transparent background
                        .clipShape(Circle()) // Circular shape
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        coPilotRef?.togglePause()
                    }) {
                        Image(systemName: "pause.circle")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black) // Dark semi-transparent background
                            .clipShape(Circle()) 
                    }
                }
        }
    }

    private func initializeApplication() {
        // Use StoryManager to obtain the local folder path for the story.
        StoryManager.getStoryPath(for: storyID) { localPath, error in
            if let error = error {
                print(
                    "Error retrieving story folder: \(error.localizedDescription)"
                )
                return
            }

            guard let localPath = localPath else {
                print("Local path is nil.")
                return
            }

            // Store the obtained local folder URL for later use.
            self.storyFolderURL = localPath

            // Start the local server using the obtained folder path.
            startLocalServer(with: localPath) { success in
                if success {
                    log.info(
                        "Local server started successfully for story: \(storyID)."
                    )
                } else {
                    log.error(
                        "Failed to start the local server for story: \(storyID)."
                    )
                }
            }
        }
    }

    private func loadCopilot() {
        guard let jsonManifest = loadJsonManifest() else {
            print("Failed to load JSON manifest.")
            return
        }

        let coPilot = CoPilot(
            conversationalAIViewModel: conversationalAIViewModel,
            storyFolder: storyFolderURL)
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

        subtitleViewModel.updateSubtitles(
            content: content, characters: chars, timings: timings)

        if !chars.isEmpty && !timings.isEmpty {
            // Timed mode: start playback using the timer.
            subtitleViewModel.startPlayback()
        } else {
            // Plain text mode: simply display the content immediately.
            subtitleViewModel.currentChunk = content
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

    private func startLocalServer(
        with folderURL: URL, completion: @escaping (Bool) -> Void
    ) {
        print("Starting server using folder: \(folderURL.path)")

        DispatchQueue.global(qos: .background).async {
            let folderPath = folderURL.path
            if let urlString = server.startServer(folderPath: folderPath),
                let url = URL(string: urlString)
            {
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

    /// Loads the JSON manifest from the story's local folder.
    /// Instead of a fixed bundle path, it uses the local folder URL (obtained when starting the server)
    /// and appends the relative path "playbook/en-US/default.json".
    private func loadJsonManifest() -> String? {
        guard let storyFolderURL = storyFolderURL else {
            print("Story folder URL is nil.")
            return nil
        }

        // Build the full URL to the JSON manifest file.
        // TODO: switch language later
        let manifestURL = storyFolderURL.appendingPathComponent(
            "playbooks/en-US/default.json")
        do {
            let jsonData = try String(contentsOf: manifestURL, encoding: .utf8)
            return jsonData
        } catch {
            print(
                "Failed to read JSON file at \(manifestURL.path): \(error.localizedDescription)"
            )
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
class HostingController<Content>: UIHostingController<Content>
where Content: View {
    override var prefersStatusBarHidden: Bool {
        true  // Return true to hide the status bar
    }
}
