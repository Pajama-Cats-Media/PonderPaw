import AVFoundation
import RxSwift

class ReadActionHandler: NSObject {
    private var audioPlayer: AVAudioPlayer?
    private var playbackCompletion: (() -> Void)?
    
    private var storyFolder: URL?
    
    // Then add this initializer:
    init(storyFolder: URL?) {
        self.storyFolder = storyFolder
        super.init()
    }

    func read(action: [String: Any]) -> Observable<Void> {
        return Observable<Void>.create { observer in
            if let audioFile = action["audio"] as? String {
                // Play audio file
                guard let storyFolder = self.storyFolder else {
                    print("Story folder is not available.")
                    observer.onCompleted()
                    return Disposables.create()
                }
                let audioFileURL = storyFolder.appendingPathComponent("sounds/en-US/\(audioFile)")
                do {
                    self.audioPlayer = try AVAudioPlayer(contentsOf: audioFileURL)
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
