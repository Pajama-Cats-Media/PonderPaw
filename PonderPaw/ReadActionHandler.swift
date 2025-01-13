import AVFoundation
import RxSwift

class ReadActionHandler: NSObject {
    private var audioPlayer: AVAudioPlayer?
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var playbackCompletion: (() -> Void)?

    func read(action: [String: Any]) -> Observable<Void> {
        return Observable<Void>.create { observer in
            if let audioFile = action["audio"] as? String {
                // Play audio file
                guard let filePath = Bundle.main.path(forResource: audioFile, ofType: nil, inDirectory: "book/sounds/en-US") else {
                    print("Audio file not found: \(audioFile)")
                    observer.onCompleted()
                    return Disposables.create()
                }

                do {
                    let fileURL = URL(fileURLWithPath: filePath)
                    self.audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                    self.audioPlayer?.delegate = self
                    self.playbackCompletion = {
                        observer.onCompleted()
                    }
                    self.audioPlayer?.play()
                } catch {
                    print("Error initializing audio player: \(error.localizedDescription)")
                    observer.onCompleted()
                }

                return Disposables.create {
                    self.stopAudioPlayback()
                }
            } else if let content = action["content"] as? String {
                // Use TTS
                let utterance = AVSpeechUtterance(string: content)
                utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                self.speechSynthesizer.delegate = self

                self.playbackCompletion = {
                    observer.onCompleted()
                }
                self.speechSynthesizer.speak(utterance)

                return Disposables.create {
                    self.stopTTSPlayback()
                }
            } else {
                print("Invalid action: missing both 'audio' and 'content' fields.")
                observer.onCompleted() // Complete even for invalid action
                return Disposables.create()
            }
        }
    }

    private func stopAudioPlayback() {
        if let player = audioPlayer {
            player.stop()
            audioPlayer = nil
        }
        playbackCompletion = nil
    }

    private func stopTTSPlayback() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        playbackCompletion = nil
    }
}

// MARK: - AVAudioPlayerDelegate
extension ReadActionHandler: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("Audio playback finished with success: \(flag)")
        playbackCompletion?()
        playbackCompletion = nil
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension ReadActionHandler: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("TTS playback finished successfully.")
        playbackCompletion?()
        playbackCompletion = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("TTS playback was canceled.")
        playbackCompletion?()
        playbackCompletion = nil
    }
}
