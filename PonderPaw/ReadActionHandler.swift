import AVFoundation
import RxSwift

class ReadActionHandler: NSObject {
    private var audioPlayer: AVAudioPlayer?
    private var playbackCompletion: (() -> Void)? // Closure to notify playback completion
    private let speechSynthesizer = AVSpeechSynthesizer()

    func read(action: [String: Any]) -> Observable<Void> {
        return Observable<Void>.create { observer in
            if let audioFile = action["audio"] as? String {
                // Construct the path using Bundle
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
                    // Stop playback and clear resources if the observer is disposed
                    self.audioPlayer?.stop()
                    self.audioPlayer = nil
                    self.playbackCompletion = nil
                }
            } else if let content = action["content"] as? String {
                // Use TTS to read the content
                let utterance = AVSpeechUtterance(string: content)
                utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                self.speechSynthesizer.delegate = self

                self.playbackCompletion = {
                    observer.onCompleted()
                }
                self.speechSynthesizer.speak(utterance)

                return Disposables.create {
                    // Stop TTS and clear resources if the observer is disposed
                    self.speechSynthesizer.stopSpeaking(at: .immediate)
                    self.playbackCompletion = nil
                }
            } else {
                print("Invalid action: missing both 'audio' and 'content' fields.")
                observer.onError(NSError(domain: "ReadActionHandler", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing 'audio' and 'content' fields"]))
                return Disposables.create()
            }
        }
    }
}

extension ReadActionHandler: AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("Audio playback finished with success: \(flag)")
        playbackCompletion?()
        playbackCompletion = nil
    }

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
