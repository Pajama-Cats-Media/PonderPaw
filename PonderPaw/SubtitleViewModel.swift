import Foundation
import Combine

class SubtitleViewModel: ObservableObject {
    @Published var currentSubtitle: String = ""
    @Published var content: String = "" // Full content displayed as the back layer

    private var model: SubtitleModel
    private var timer: Timer?
    private var startTime: Date?

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

        AppLogger.shared.logInfo(category: "subtitle", message: "Starting subtitle playback...")
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateSubtitle()
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
        stopPlayback() // Stop current playback
        model = SubtitleModel(content: content, characters: chars, timings: timings) // Update the model
        self.content = content // Update the back layer content
        AppLogger.shared.logInfo(category: "subtitle", message: "Subtitle model updated with new data.")
        startPlayback() // Restart playback with updated data
    }

    /// Updates the current subtitle based on the elapsed time.
    private func updateSubtitle() {
        guard let startTime = startTime else { return }
        let elapsedTime = Date().timeIntervalSince(startTime)
        currentSubtitle = model.getSubtitleText(at: elapsedTime)
        AppLogger.shared.logInfo(category: "subtitle", message: "Current Subtitle Updated: \(currentSubtitle)")
    }
}
