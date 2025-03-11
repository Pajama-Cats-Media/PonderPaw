import Foundation
import Combine

class SubtitleViewModel: ObservableObject {
    @Published var currentChunk: String = "" // The current subtitle chunk
    @Published var isPaused: Bool = false // Track pause state

    @Published var model: SubtitleModel
    private var timer: Timer?
    private var startTime: Date?
    private var elapsedTime: TimeInterval = 0 // Store elapsed time on pause

    init(model: SubtitleModel) {
        self.model = model
    }

    /// Starts or resumes subtitle playback
    func startPlayback() {
        guard model.isValid else {
            print("Invalid subtitle data.")
            return
        }
        
        if model.isPlainText {
            currentChunk = model.getCurrentChunk(at: 0)
            return
        }

        if isPaused {
            // Resume from paused state
            startTime = Date().addingTimeInterval(-elapsedTime)
            isPaused = false
        } else {
            // Start from the beginning
            startTime = Date()
            elapsedTime = 0
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updatePlayback()
        }
    }

    /// Pauses subtitle playback
    func pausePlayback() {
        guard let startTime = startTime else { return }

        elapsedTime = Date().timeIntervalSince(startTime) // Save elapsed time
        timer?.invalidate()
        timer = nil
        isPaused = true
    }

    /// Stops subtitle playback
    func stopPlayback() {
        timer?.invalidate()
        timer = nil
        isPaused = false
        elapsedTime = 0
    }

    /// Updates the subtitle content
    func updateSubtitles(content: String, characters: [String], timings: [Double]) {
        model.updateSubtitle(content: content, characters: characters, timings: timings)
        startPlayback()
    }

    /// Updates the current chunk based on elapsed time
    private func updatePlayback() {
        guard let startTime = startTime, !isPaused else { return }
        let elapsedTime = Date().timeIntervalSince(startTime)

        // Fetch the current chunk
        currentChunk = model.getCurrentChunk(at: elapsedTime)
    }
}
