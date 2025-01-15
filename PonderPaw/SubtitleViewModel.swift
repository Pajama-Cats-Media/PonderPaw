import Foundation
import Combine

class SubtitleViewModel: ObservableObject {
    @Published var currentChunk: String = "" // The current subtitle chunk

    private var model: SubtitleModel
    private var timer: Timer?
    private var startTime: Date?

    init(model: SubtitleModel) {
        self.model = model
    }

    /// Starts subtitle playback
    func startPlayback() {
        guard model.isValid else {
            print("Invalid subtitle data.")
            return
        }

        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updatePlayback()
        }
    }

    /// Stops subtitle playback
    func stopPlayback() {
        timer?.invalidate()
        timer = nil
    }

    /// Updates the subtitle content
    func updateSubtitles(content: String, characters: [String], timings: [Double]) {
        model.updateSubtitle(content: content, characters: characters, timings: timings)
        startPlayback()
    }

    /// Updates the current chunk based on elapsed time
    private func updatePlayback() {
        guard let startTime = startTime else { return }
        let elapsedTime = Date().timeIntervalSince(startTime)

        // Fetch the current chunk
        currentChunk = model.getCurrentChunk(at: elapsedTime)
    }
}
