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

    func playAudio(filePath: String) -> Observable<Void> {
        return Observable<Void>.create { observer in
            do {
                let fileURL = URL(fileURLWithPath: filePath)
                self.audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                self.audioPlayer?.delegate = self
                self.audioPlayer?.play()

                // Notify observer on completion
                NotificationCenter.default.addObserver(forName: NSNotification.Name.AVAudioPlayerDidFinishPlaying, object: nil, queue: .main) { _ in
                    observer.onCompleted()
                    NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVAudioPlayerDidFinishPlaying, object: nil)
                }
            } catch {
                print("Error initializing audio player: \(error.localizedDescription)")
                observer.onCompleted()
            }

            return Disposables.create()
        }
    }
}

extension ReadActionHandler: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("Audio playback finished with success: \(flag)")
    }
}
