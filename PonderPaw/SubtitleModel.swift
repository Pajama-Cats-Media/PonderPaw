import Foundation

class SubtitleModel {
    struct Subtitle {
        let content: String
        let characters: [String]
        let timings: [Double]
        let chunks: [String]
    }

    private let subtitle: Subtitle
    private var currentChunkIndex: Int = 0

    /// Expose the content property for ViewModel compatibility
    var content: String {
        subtitle.content
    }

    init(content: String, characters: [String], timings: [Double], maxChunkLength: Int = 40) {
        // Generate chunks before initializing properties
        let chunks = SubtitleModel.breakSubtitleIntoChunks(text: content, maxLength: maxChunkLength)
        self.subtitle = Subtitle(content: content, characters: characters, timings: timings, chunks: chunks)
    }

    var isValid: Bool {
        !subtitle.characters.isEmpty && subtitle.characters.count == subtitle.timings.count
    }

    func getChunks() -> [String] {
        return subtitle.chunks
    }

    /// Returns the entire subtitle sentence up to the current time.
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

    /// Breaks the subtitle content into chunks for rotation.
    static func breakSubtitleIntoChunks(text: String, maxLength: Int) -> [String] {
        var chunks: [String] = []
        var currentChunk = ""

        for word in text.split(separator: " ") {
            if currentChunk.count + word.count + 1 > maxLength {
                chunks.append(currentChunk)
                currentChunk = ""
            }
            currentChunk += (currentChunk.isEmpty ? "" : " ") + word
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }

        return chunks
    }
}
