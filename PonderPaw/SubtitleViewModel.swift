import Foundation
import Combine

class SubtitleViewModel: ObservableObject {
    @Published var currentSubtitle: String = ""

    private let model: SubtitleModel
    private var timer: Timer?
    private var startTime: Date?

    init(model: SubtitleModel) {
        self.model = model
    }

    func startPlayback() {
        guard model.isValid else {
            AppLogger.shared.logError(category: "subtitle", message: "Invalid subtitle data.")
            return
        }

        AppLogger.shared.logError(category: "subtitle", message: "Starting subtitle playback...")
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateSubtitle()
        }
    }

    func stopPlayback() {
        timer?.invalidate()
        timer = nil
        AppLogger.shared.logError(category: "subtitle", message: "Subtitle playback stopped.")
    }

    private func updateSubtitle() {
        guard let startTime = startTime else { return }
        let elapsedTime = Date().timeIntervalSince(startTime)
        currentSubtitle = model.getSubtitleText(at: elapsedTime)
        AppLogger.shared.logError(category: "subtitle", message: "Current Subtitle Updated: \(currentSubtitle)")
    }
}
