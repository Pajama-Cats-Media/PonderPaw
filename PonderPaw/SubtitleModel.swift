import Foundation

class SubtitleModel {
    struct Subtitle {
        let content: String
        let characters: [String]
        let timings: [Double]
    }

    private var subtitle: Subtitle
    private let maxChunkLength: Int = 40 // Maximum characters per chunk (constant)

    init(content: String, characters: [String], timings: [Double]) {
        self.subtitle = Subtitle(content: content, characters: characters, timings: timings)
    }

    var isValid: Bool {
        !subtitle.characters.isEmpty && subtitle.characters.count == subtitle.timings.count
    }

    /// Updates the subtitle data
    func updateSubtitle(content: String, characters: [String], timings: [Double]) {
        self.subtitle = Subtitle(content: content, characters: characters, timings: timings)
    }

    /// Calculates chunks and their start timings dynamically (syncing with audio)
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

            // Ensure chunks are split only at word boundaries
            if currentChunk.count >= maxChunkLength && char == " " {
                if let startTiming = chunkStartTiming {
                    chunks.append(currentChunk.trimmingCharacters(in: .whitespaces))
                    chunkTimings.append(startTiming)
                }
                currentChunk = ""
                chunkStartTiming = nil
            }

            // Create a new chunk for punctuation or when max chunk length is reached
            if char == "." || char == "!" || char == "?" {
                if let startTiming = chunkStartTiming {
                    chunks.append(currentChunk.trimmingCharacters(in: .whitespaces))
                    chunkTimings.append(startTiming)
                }
                currentChunk = ""
                chunkStartTiming = nil
            }
        }

        // Add the last chunk if it exists
        if !currentChunk.isEmpty, let startTiming = chunkStartTiming {
            chunks.append(currentChunk.trimmingCharacters(in: .whitespaces))
            chunkTimings.append(startTiming)
        }

        return (chunks, chunkTimings)
    }

    /// Returns the current chunk based on elapsed time
    func getCurrentChunk(at time: Double) -> String {
        let (chunks, chunkTimings) = calculateChunksAndTimings()
        guard let index = chunkTimings.lastIndex(where: { $0 <= time }) else {
            return "" // No chunk matches the current time
        }
        return chunks[index]
    }
}
