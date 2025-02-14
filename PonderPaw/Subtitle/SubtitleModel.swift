import Foundation

class SubtitleModel {
    struct Subtitle {
        let content: String
        let characters: [String]
        let timings: [Double]
    }
    
    private var subtitle: Subtitle
    private let maxChunkLength: Int = 60 // Maximum characters per chunk (constant)
    
    // New computed property: a larger chunk length for plain text mode.
    private var effectiveMaxChunkLength: Int {
        return isPlainText ? 160 : maxChunkLength
    }
    
    init(content: String, characters: [String], timings: [Double]) {
        self.subtitle = Subtitle(content: content, characters: characters, timings: timings)
    }
    
    // support both timing subtitle or plain content
    var isValid: Bool {
        if subtitle.characters.isEmpty && subtitle.timings.isEmpty {
            return !subtitle.content.isEmpty
        }
        return !subtitle.characters.isEmpty && subtitle.characters.count == subtitle.timings.count
    }
    
    var isPlainText: Bool {
        subtitle.characters.isEmpty && subtitle.timings.isEmpty
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
        let punctuationSet: Set<Character> = [".", ",", "!", "?", "'", "\""]
        
        for (index, char) in subtitle.characters.enumerated() {
            let timing = subtitle.timings[index]
            
            if chunkStartTiming == nil {
                chunkStartTiming = timing
            }
            
            currentChunk += char
            
            // Ensure chunks are split only at word boundaries and avoid cutting punctuation
            if currentChunk.count >= effectiveMaxChunkLength {
                if char == " " || punctuationSet.contains(char) {
                    if let startTiming = chunkStartTiming {
                        chunks.append(currentChunk.trimmingCharacters(in: .whitespaces))
                        chunkTimings.append(startTiming)
                    }
                    currentChunk = ""
                    chunkStartTiming = nil
                }
            }
            
            // Create a new chunk for punctuation or when max chunk length is reached
            if punctuationSet.contains(char) && currentChunk.count >= effectiveMaxChunkLength - 1 {
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
    
    func getCurrentChunk(at time: Double) -> String {
        if isPlainText {
            return subtitle.content
        }
        let (chunks, chunkTimings) = calculateChunksAndTimings()
        guard let index = chunkTimings.lastIndex(where: { $0 <= time }) else {
            return ""
        }
        return chunks[index]
    }
}
