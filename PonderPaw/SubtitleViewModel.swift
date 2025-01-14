import Foundation
import Combine

class SubtitleViewModel: ObservableObject {
    @Published var currentSubtitle: String = ""

    private let model: SubtitleModel
    private var timer: Timer?
    private var startTime: Date?
    private var cancellables: Set<AnyCancellable> = []

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
            self?.updateSubtitle()
        }
    }

    func stopPlayback() {
        timer?.invalidate()
        timer = nil
    }

    private func updateSubtitle() {
        guard let startTime = startTime else { return }
        let elapsedTime = Date().timeIntervalSince(startTime)
        currentSubtitle = model.getSubtitleText(at: elapsedTime)
    }
}
