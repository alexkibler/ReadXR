//
//  BackgroundAudioManager.swift
//  ReadXR
//
//  Created by Gemini CLI on 4/19/26.
//

import Foundation
import AVFoundation
import MediaPlayer

/// Manages the background audio session and remote command center (lock screen controls).
/// This keeps the app alive when the screen is locked and maps media controls to page turns.
@MainActor
final class BackgroundAudioManager: NSObject, AVAudioPlayerDelegate {
    static let shared = BackgroundAudioManager()
    
    private var audioPlayer: AVAudioPlayer?
    private let appState = AppState.shared
    
    private override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
    }
    
    /// Configures the AVAudioSession to allow background playback.
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    /// Starts looping a silent audio file to prevent the app from being suspended.
    func startBackgroundAudio() {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        guard let asset = NSDataAsset(name: "silence") else {
            // Fallback to looking for a file in the bundle if not in Assets.xcassets
            guard let url = Bundle.main.url(forResource: "silence", withExtension: "wav") else {
                print("Error: silence.wav not found. Background keep-alive will not work.")
                return
            }
            playAudio(from: url)
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(data: asset.data)
            audioPlayer?.delegate = self
            audioPlayer?.numberOfLoops = -1 // Loop infinitely
            audioPlayer?.volume = 0.01 // Minimal volume (effectively silent)
            audioPlayer?.play()
            print("Background audio started (Asset)")
        } catch {
            print("Failed to play background audio: \(error)")
        }
    }
    
    private func playAudio(from url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 0.01
            audioPlayer?.play()
            print("Background audio started (File URL)")
        } catch {
            print("Failed to play background audio: \(error)")
        }
    }
    
    /// Hijacks the lock screen / Apple Watch media controls.
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Map "Next Track" to Page Forward
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            Task { @MainActor in
                AppState.shared.pageForward()
                self?.updateNowPlaying()
            }
            return .success
        }
        
        // Map "Previous Track" to Page Backward
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            Task { @MainActor in
                AppState.shared.pageBackward()
                self?.updateNowPlaying()
            }
            return .success
        }
        
        // Disable play/pause as they don't apply to this "reader" mode
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
    }
    
    func updateNowPlaying() {
        var nowPlayingInfo = [String: Any]()
        
        // Display progress (e.g., Chapter 3 / 12)
        let progress = "Chapter \(appState.currentChapterIndex + 1) of \(max(1, appState.totalChapters))"
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = progress
        nowPlayingInfo[MPMediaItemPropertyArtist] = appState.bookTitle
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = appState.bookAuthor
        
        // If we have a cover image in the future, it would go here:
        // nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
