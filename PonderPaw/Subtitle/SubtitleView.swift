import SwiftUI

// Add this extension to auto-wrap plain text based on a maximum line length.
extension String {
    func autoWrap(maxLineLength: Int) -> String {
        var currentLine = ""
        var result = ""
        let words = self.split(separator: " ")
        for word in words {
            if currentLine.count + word.count + (currentLine.isEmpty ? 0 : 1) > maxLineLength {
                result += (result.isEmpty ? "" : "\n") + currentLine
                currentLine = String(word)
            } else {
                currentLine += (currentLine.isEmpty ? "" : " ") + word
            }
        }
        if !currentLine.isEmpty {
            result += (result.isEmpty ? "" : "\n") + currentLine
        }
        return result
    }
}

struct SubtitleView: View {
    @ObservedObject var viewModel: SubtitleViewModel
    
    var body: some View {
        if !viewModel.currentChunk.isEmpty {
            let isPlainMode = viewModel.model.isPlainText // Access the model's flag
            let displayText = isPlainMode ? viewModel.currentChunk.autoWrap(maxLineLength: 60) : viewModel.currentChunk
            Text(displayText)
                .font(.system(size: 20))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: isPlainMode ? 160 : 40, alignment: .center)
                // When in plain text mode, let the text wrap to multiple lines
                .lineLimit(isPlainMode ? nil : 1)
                // Ensure the Text view can expand vertically to show all lines
                .fixedSize(horizontal: false, vertical: true)
                .background(Color.black.opacity(0.8))
                .onAppear {
                    viewModel.startPlayback()
                }
                .onDisappear {
                    viewModel.stopPlayback()
                }
        }
    }
}
