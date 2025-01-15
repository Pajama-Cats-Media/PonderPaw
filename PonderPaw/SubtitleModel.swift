import Foundation

class SubtitleModel {
    struct Subtitle {
        let content: String
        let characters: [String]
        let timings: [Double]
    }

    private let subtitle: Subtitle

    init(content: String, characters: [String], timings: [Double]) {
        self.subtitle = Subtitle(content: content, characters: characters, timings: timings)
    }

    var isValid: Bool {
        !subtitle.characters.isEmpty && subtitle.characters.count == subtitle.timings.count
    }

    func getHighlightedText(at time: Double) -> String {
        guard isValid else { return "" }
        var highlightedText = ""
        for (index, timing) in subtitle.timings.enumerated() {
            if timing <= time {
                highlightedText += subtitle.characters[index]
            } else {
                break
            }
        }
        return highlightedText
    }

    func getCurrentChunk(at time: Double) -> String {
        guard isValid else { return "" }
        var currentChunk = ""
        var previousTime = 0.0
        for (index, timing) in subtitle.timings.enumerated() {
            if timing > time {
                break
            }
            if timing - previousTime > 2.5 { // Adjust chunking threshold as needed
                currentChunk += subtitle.characters[index]
            } else {
                currentChunk += subtitle.characters[index]
            }
            previousTime = timing
        }
        return currentChunk
    }
}
