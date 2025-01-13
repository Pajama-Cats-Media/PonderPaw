//
//  ReadActionHandler.swift
//  PonderPaw
//
//  Created by Homer Quan on 1/13/25.
//

import AVFoundation
import RxSwift

class ReadActionHandler: NSObject {
    private var audioPlayer: AVAudioPlayer?
    private var playbackCompletion: (() -> Void)? // Closure to notify playback completion

    func read(action: [String: Any]) -> Observable<Void> {
        return Observable<Void>.create { observer in
            guard let audioFile = action["audio"] as? String else {
                print("Invalid action: missing 'audio' field.")
                observer.onCompleted()
                return Disposables.create()
            }

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
        }
    }
}

extension ReadActionHandler: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("Audio playback finished with success: \(flag)")
        playbackCompletion?()
        playbackCompletion = nil
    }
}
