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
        print("🎵 [BackgroundAudioManager] INIT started")
        setupAudioSession()
        setupRemoteCommandCenter()
        print("🎵 [BackgroundAudioManager] INIT finished")
    }
    
    /// Configures the AVAudioSession to allow background playback.
    private func setupAudioSession() {
        print("🎵 [BackgroundAudioManager] Setting up AudioSession...")
        let exclusive = appState.lockScreenControls
        applyMixingPreference(exclusive)
    }

    /// Reconfigures the audio session mixing mode at runtime.
    /// - Parameter exclusive: `true` = take audio focus (enables lock screen widget); `false` = mix with others.
    func applyMixingPreference(_ exclusive: Bool) {
        do {
            let session = AVAudioSession.sharedInstance()
            let options: AVAudioSession.CategoryOptions = exclusive ? [] : [.mixWithOthers]
            try session.setCategory(.playback, mode: .default, options: options)
            try session.setActive(true)
            print("🎵 [BackgroundAudioManager] AudioSession reconfigured. exclusive=\(exclusive)")
        } catch {
            print("🎵 [BackgroundAudioManager] Failed to configure audio session: \(error)")
        }
    }
    
    /// Starts looping a silent audio file to prevent the app from being suspended.
    func startBackgroundAudio() {
        print("🎵 [BackgroundAudioManager] startBackgroundAudio() called")
        UIApplication.shared.beginReceivingRemoteControlEvents()
        print("🎵 [BackgroundAudioManager] Called beginReceivingRemoteControlEvents()")
        
        guard let asset = NSDataAsset(name: "silence") else {
            print("🎵 [BackgroundAudioManager] NSDataAsset 'silence' not found, falling back to Bundle.main.url...")
            // Fallback to looking for a file in the bundle if not in Assets.xcassets
            guard let url = Bundle.main.url(forResource: "silence", withExtension: "wav") else {
                print("🎵 [BackgroundAudioManager] Error: silence.wav not found in bundle. Background keep-alive will NOT work.")
                return
            }
            playAudio(from: url)
            return
        }
        
        print("🎵 [BackgroundAudioManager] Found 'silence' asset, initializing AVAudioPlayer...")
        do {
            audioPlayer = try AVAudioPlayer(data: asset.data)
            audioPlayer?.delegate = self
            audioPlayer?.numberOfLoops = -1 // Loop infinitely
            audioPlayer?.volume = 0.01 // Minimal volume (effectively silent)
            audioPlayer?.play()
            print("🎵 [BackgroundAudioManager] Background audio started (Asset)")
        } catch {
            print("🎵 [BackgroundAudioManager] Failed to play background audio: \(error)")
        }
    }
    
    private func playAudio(from url: URL) {
        print("🎵 [BackgroundAudioManager] playAudio(from: \(url.lastPathComponent))")
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 0.01
            audioPlayer?.play()
            print("🎵 [BackgroundAudioManager] Background audio started (File URL)")
        } catch {
            print("🎵 [BackgroundAudioManager] Failed to play background audio: \(error)")
        }
    }
    
    /// Hijacks the lock screen / Apple Watch media controls.
    private func setupRemoteCommandCenter() {
        print("🎵 [BackgroundAudioManager] setupRemoteCommandCenter() called")
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
        
        // Enable play/pause so iOS shows the Now Playing UI, even though they don't do anything
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { _ in .success }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { _ in .success }
    }
    
    func updateNowPlaying() {
        print("🎵 [BackgroundAudioManager] updateNowPlaying() called. Book: '\(appState.bookTitle)'")
        var nowPlayingInfo = [String: Any]()
        
        // Display progress (e.g., Chapter 3 / 12)
        let progress = "Chapter \(appState.currentChapterIndex + 1) of \(max(1, appState.totalChapters))"
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = progress
        nowPlayingInfo[MPMediaItemPropertyArtist] = appState.bookTitle
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = appState.bookAuthor
        
        // If we have a cover image in the future, it would go here:
        // nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0.0
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = Double(max(1, appState.totalChapters))

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        print("🎵 [BackgroundAudioManager] nowPlayingInfo updated")
    }
}
