import Foundation

class SubtitleModel {
    struct Subtitle {
        let characters: [String]
        let timings: [Double]
    }

    private let subtitle: Subtitle

    init(characters: [String], timings: [Double]) {
        self.subtitle = Subtitle(characters: characters, timings: timings)
    }

    var isValid: Bool {
        !subtitle.characters.isEmpty && subtitle.characters.count == subtitle.timings.count
    }

    func getSubtitleText(at time: Double) -> String {
        guard isValid else { return "" }
        var subtitleText = ""
        for (index, timing) in subtitle.timings.enumerated() {
            if timing <= time {
                subtitleText += subtitle.characters[index]
            } else {
                break
            }
        }
        return subtitleText
    }
}
