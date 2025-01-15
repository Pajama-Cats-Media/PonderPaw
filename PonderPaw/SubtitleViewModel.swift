import Foundation
import Combine

class SubtitleViewModel: ObservableObject {
    @Published var currentChunk: String = ""
    @Published var highlightedText: String = ""

    private var model: SubtitleModel
    private var timer: Timer?
    private var startTime: Date?

    init(model: SubtitleModel) {
        self.model = model
    }

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

    func stopPlayback() {
        timer?.invalidate()
        timer = nil
    }

    func updateSubtitles(content: String, chars: [String], timings: [Double]) {
        stopPlayback()
        model = SubtitleModel(content: content, characters: chars, timings: timings)
        startPlayback()
    }

    private func updatePlayback() {
        guard let startTime = startTime else { return }
        let elapsedTime = Date().timeIntervalSince(startTime)

        // Update highlighted text and current chunk
        highlightedText = model.getHighlightedText(at: elapsedTime)
        currentChunk = model.getCurrentChunk(at: elapsedTime)
    }
}
