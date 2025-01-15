import Foundation

class SubtitleModel {
    struct Subtitle {
        let content: String
        let characters: [String]
        let timings: [Double]
    }

    private var subtitle: Subtitle
    private var maxChunkLength: Int

    init(content: String, characters: [String], timings: [Double], maxChunkLength: Int = 40) {
        self.subtitle = Subtitle(content: content, characters: characters, timings: timings)
        self.maxChunkLength = maxChunkLength
    }

    var isValid: Bool {
        !subtitle.characters.isEmpty && subtitle.characters.count == subtitle.timings.count
    }

    func updateSubtitle(content: String, characters: [String], timings: [Double], maxChunkLength: Int = 40) {
        self.subtitle = Subtitle(content: content, characters: characters, timings: timings)
        self.maxChunkLength = maxChunkLength
    }

    /// Calculates chunks and their start timings dynamically
    func calculateChunksAndTimings() -> ([String], [Double]) {
        var chunks: [String] = []
        var chunkTimings: [Double] = []

        var currentChunk = ""
        var chunkStartTiming: Double? = nil

        for (index, char) in subtitle.characters.enumerated() {
            let timing = subtitle.timings[index]

            if chunkStartTiming == nil {
                chunkStartTiming = timing
            }

            currentChunk += char

            // Create a new chunk when reaching max length or sentence-ending punctuation
            if currentChunk.count >= maxChunkLength || char == "." || char == "!" || char == "?" {
                if let startTiming = chunkStartTiming {
                    chunks.append(currentChunk)
                    chunkTimings.append(startTiming)
                }
                currentChunk = ""
                chunkStartTiming = nil
            }
        }

        // Add the last chunk if it exists
        if !currentChunk.isEmpty, let startTiming = chunkStartTiming {
            chunks.append(currentChunk)
            chunkTimings.append(startTiming)
        }

        return (chunks, chunkTimings)
    }

    /// Gets the current chunk based on elapsed time
    func getCurrentChunk(at time: Double) -> String {
        let (chunks, chunkTimings) = calculateChunksAndTimings()
        let index = chunkTimings.lastIndex(where: { $0 <= time }) ?? 0
        return chunks[index]
    }
}
