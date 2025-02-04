import AVFoundation
import RxSwift

class ReadActionHandler: NSObject {
    private var audioPlayer: AVAudioPlayer?
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
                        observer.onCompleted() // Notify completion of the observable
                    }
                    self.audioPlayer?.play()
                } catch {
                    print("Error initializing audio player: \(error.localizedDescription)")
                    observer.onCompleted()
                }

                // Return cleanup logic for when the subscription is disposed
                return Disposables.create {
                    self.stopAudioPlayback() // Cleanup when the audio is complete or subscription is disposed
                }
            } else {
                print("Invalid action: missing 'audio' field.")
                observer.onCompleted() // Notify completion for invalid actions
                return Disposables.create()
            }
        }
    }


    private func stopAudioPlayback() {
        guard let player = audioPlayer else { return }
        
        let fadeOutDuration: TimeInterval = 1.0 // 1 second fade-out
        let fadeOutSteps = 10 // Reduce volume in 10 small steps
        let fadeOutInterval = fadeOutDuration / Double(fadeOutSteps) // 100ms per step
        
        var currentStep = 0
        
        // using fade out
        Timer.scheduledTimer(withTimeInterval: fadeOutInterval, repeats: true) { timer in
            if currentStep < fadeOutSteps {
                let newVolume = max(0, player.volume - (1.0 / Float(fadeOutSteps))) // Decrease volume smoothly
                player.volume = newVolume
                currentStep += 1
            } else {
                timer.invalidate()
                player.stop()
                self.audioPlayer = nil
                self.playbackCompletion = nil
            }
        }
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
