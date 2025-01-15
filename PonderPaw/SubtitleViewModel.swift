import Foundation
import Combine

class SubtitleViewModel: ObservableObject {
    @Published var currentChunk: String = ""
    @Published var highlightedText: String = ""
    @Published var content: String = "" // Full content displayed as the back layer

    private var model: SubtitleModel
    private var timer: Timer?
    private var startTime: Date?
    private var chunkIndex: Int = 0

    init(model: SubtitleModel) {
        self.model = model
        self.content = model.content
    }

    /// Starts subtitle playback using the current subtitle model.
    func startPlayback() {
        guard model.isValid else {
            AppLogger.shared.logError(category: "subtitle", message: "Invalid subtitle data.")
            return
        }

        chunkIndex = 0
        startTime = Date()
        updateCurrentChunk()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updatePlayback()
        }
    }

    /// Stops subtitle playback and invalidates the timer.
    func stopPlayback() {
        timer?.invalidate()
        timer = nil
        AppLogger.shared.logInfo(category: "subtitle", message: "Subtitle playback stopped.")
    }

    /// Updates the subtitle model with new characters, timings, and content.
    func updateSubtitles(content: String, chars: [String], timings: [Double]) {
        stopPlayback()
        model = SubtitleModel(content: content, characters: chars, timings: timings)
        self.content = content
        startPlayback()
    }

    /// Handles the playback progression, including rotation and highlighting.
    private func updatePlayback() {
        guard let startTime = startTime else { return }

        let elapsedTime = Date().timeIntervalSince(startTime)
        highlightedText = model.getHighlightedText(at: elapsedTime)

        let chunks = model.getChunks()
        if chunkIndex < chunks.count {
            currentChunk = chunks[chunkIndex]
            if elapsedTime > Double(chunkIndex + 1) * 2.0 { // Adjust timing as needed
                chunkIndex += 1
            }
        }
    }

    /// Updates the current chunk based on the rotation index.
    private func updateCurrentChunk() {
        let chunks = model.getChunks()
        if chunkIndex < chunks.count {
            currentChunk = chunks[chunkIndex]
        }
    }
}
