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
    
    func read(action: [String: Any], pause: Observable<Bool> = Observable.just(false)) -> Observable<Void> {
        return Observable<Void>.create { observer in
            // Immediately stop any currently playing audio before starting a new one
            self.stopAudioPlaybackNow()
            
            if let audioFile = action["audio"] as? String {
                // Play audio file
                guard let storyFolder = self.storyFolder else {
                    print("Story folder is not available.")
                    observer.onCompleted()
                    return Disposables.create()
                }
                let audioFileURL = storyFolder.appendingPathComponent("sounds/en-US/\(audioFile)")
                
                do {
                    // Allow play in silent mode
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                    try AVAudioSession.sharedInstance().setActive(true)
                    
                    self.audioPlayer = try AVAudioPlayer(contentsOf: audioFileURL)
                    self.audioPlayer?.delegate = self
                    self.playbackCompletion = {
                        observer.onCompleted() // Notify completion of the observable
                    }
                    
                    self.audioPlayer?.play() // Default behavior: Start playing
                    
                    // Observe the pause state dynamically
                    let pauseSubscription = pause.subscribe(onNext: { isPaused in
                        if isPaused {
                            self.audioPlayer?.pause()
                        } else {
                            self.audioPlayer?.play()
                        }
                    })
                    
                    // Return cleanup logic for when the subscription is disposed
                    return Disposables.create {
                        pauseSubscription.dispose() // Dispose pause observer
                        self.stopAudioPlaybackNow() // Cleanup when audio is complete or subscription is disposed
                    }
                } catch {
                    print("Error initializing audio player: \(error.localizedDescription)")
                    observer.onCompleted()
                    return Disposables.create()
                }
            } else {
                print("Invalid action: missing 'audio' field.")
                observer.onCompleted() // Notify completion for invalid actions
                return Disposables.create()
            }
        }
    }
    
    private func stopAudioPlaybackNow() {
            if let player = audioPlayer {
                player.stop()
                audioPlayer = nil
            }
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
