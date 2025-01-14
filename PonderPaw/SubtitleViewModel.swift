import Foundation
import Combine

class SubtitleViewModel: ObservableObject {
    @Published var currentSubtitle: String = ""

    private var model: SubtitleModel
    private var timer: Timer?
    private var startTime: Date?

    init(model: SubtitleModel) {
        self.model = model
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

    /// Updates the subtitle model with new characters and timings.
    func updateSubtitles(chars: [String], timings: [Double]) {
        stopPlayback() // Stop current playback
        model = SubtitleModel(characters: chars, timings: timings) // Update the model
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
