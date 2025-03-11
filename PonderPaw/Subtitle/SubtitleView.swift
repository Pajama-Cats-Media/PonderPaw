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
            let isPortrait = UIDevice.current.orientation.isPortrait
            let isIPhone = UIDevice.current.userInterfaceIdiom == .phone
            let fontSize: CGFloat = (isPortrait && isIPhone) ? 12 : 20  // Smaller font only for iPhones in portrait mode
            
            let isPlainMode = viewModel.model.isPlainText // Access the model's flag
            let displayText = isPlainMode ? viewModel.currentChunk.autoWrap(maxLineLength: 50) : viewModel.currentChunk
            
            Text(displayText)
                .font(.system(size: fontSize))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: 40, alignment: .center)
                .lineLimit(isPlainMode ? 4 : 1)
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
