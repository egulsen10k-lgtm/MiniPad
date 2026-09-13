//
//  MusicManager.swift
//  MiniPad
//

import Foundation
import Combine
import AppKit
import MediaPlayer

class MusicManager: ObservableObject {
    static let shared = MusicManager()
    
    @Published var title: String = "Not Playing"
    @Published var artist: String = ""
    @Published var album: String = ""
    @Published var isPlaying: Bool = false
    @Published var sourceApp: String = ""
    @Published var hasTrack: Bool = false
    @Published var artwork: NSImage? = nil
    
    private var timer: Timer?
    private var lastArtworkURL: String? = nil
    
    init() {
        setupObservers()
        startPolling()
        updateNowPlaying()
    }
    
    private func setupObservers() {
        let distCenter = DistributedNotificationCenter.default()
        
        // Spotify notification
        distCenter.addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateNowPlaying()
        }
        
        // Apple Music notification
        distCenter.addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateNowPlaying()
        }
    }
    
    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.updateNowPlaying()
        }
    }
    
    func updateNowPlaying() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Try AppleScript for Spotify / Apple Music first
            if let info = self.fetchFromAppleScript() {
                DispatchQueue.main.async {
                    self.title = info.title
                    self.artist = info.artist
                    self.album = info.album
                    self.isPlaying = info.isPlaying
                    self.sourceApp = info.app
                    self.hasTrack = !info.title.isEmpty && info.title != "Not Playing"
                    
                    // Fetch artwork URL if available
                    if let urlString = info.artURL, !urlString.isEmpty {
                        if urlString != self.lastArtworkURL {
                            self.lastArtworkURL = urlString
                            if let url = URL(string: urlString) {
                                URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                                    if let data = data, let image = NSImage(data: data) {
                                        DispatchQueue.main.async {
                                            self?.artwork = image
                                        }
                                    }
                                }.resume()
                            }
                        }
                    } else if self.artwork == nil {
                        // Try MPMediaInfo fallback for artwork
                        let nowPlaying = MPNowPlayingInfoCenter.default().nowPlayingInfo
                        if let artItem = nowPlaying?[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork {
                            let img = artItem.image(at: CGSize(width: 80, height: 80))
                            self.artwork = img
                        }
                    }
                }
                return
            }
            
            // Fallback to MPNowPlayingInfoCenter
            let nowPlaying = MPNowPlayingInfoCenter.default().nowPlayingInfo
            let title = nowPlaying?[MPMediaItemPropertyTitle] as? String
            let artist = nowPlaying?[MPMediaItemPropertyArtist] as? String
            let album = nowPlaying?[MPMediaItemPropertyAlbumTitle] as? String
            let rate = nowPlaying?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double
            let artItem = nowPlaying?[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork
            let image = artItem?.image(at: CGSize(width: 80, height: 80))
            
            DispatchQueue.main.async {
                self.artwork = image
                if let t = title, !t.isEmpty {
                    self.title = t
                    self.artist = artist ?? ""
                    self.album = album ?? ""
                    self.isPlaying = (rate ?? 0) > 0
                    self.sourceApp = "System"
                    self.hasTrack = true
                } else {
                    self.title = "Not Playing"
                    self.artist = ""
                    self.album = ""
                    self.isPlaying = false
                    self.sourceApp = ""
                    self.hasTrack = false
                    self.artwork = nil
                    self.lastArtworkURL = nil
                }
            }
        }
    }
    
    private func fetchFromAppleScript() -> (app: String, title: String, artist: String, album: String, isPlaying: Bool, artURL: String?)? {
        let script = """
        if application "Spotify" is running then
            tell application "Spotify"
                try
                    set tName to name of current track
                    set tArtist to artist of current track
                    set tAlbum to album of current track
                    set tState to player state as string
                    set tArt to artwork url of current track
                    return "Spotify|||" & tName & "|||" & tArtist & "|||" & tAlbum & "|||" & tState & "|||" & tArt
                on error
                    try
                        set tName to name of current track
                        set tArtist to artist of current track
                        set tAlbum to album of current track
                        set tState to player state as string
                        return "Spotify|||" & tName & "|||" & tArtist & "|||" & tAlbum & "|||" & tState & "|||"
                    on error
                        return "none"
                    end try
                end try
            end tell
        else if application "Music" is running then
            tell application "Music"
                try
                    set tName to name of current track
                    set tArtist to artist of current track
                    set tAlbum to album of current track
                    set tState to player state as string
                    return "Apple Music|||" & tName & "|||" & tArtist & "|||" & tAlbum & "|||" & tState & "|||"
                on error
                    return "none"
                end try
            end tell
        else
            return "none"
        end if
        """
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            if error == nil, let str = result.stringValue, str != "none" {
                let parts = str.components(separatedBy: "|||")
                if parts.count >= 5 {
                    let app = parts[0]
                    let title = parts[1]
                    let artist = parts[2]
                    let album = parts[3]
                    let isPlaying = parts[4].lowercased() == "playing"
                    let artURL = parts.count > 5 ? parts[5] : nil
                    return (app, title, artist, album, isPlaying, artURL?.isEmpty == true ? nil : artURL)
                }
            }
        }
        return nil
    }
    
    func togglePlayPause() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let script = """
            if application "Spotify" is running then
                tell application "Spotify" to playpause
            else if application "Music" is running then
                tell application "Music" to playpause
            end if
            """
            
            // Try AppleScript control
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
            }
            
            // Always fallback to sending media key if AppleScript is blocked
            self?.sendMediaKey(key: 16) // 16 is Play/Pause Key
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.updateNowPlaying()
            }
        }
    }
    
    func nextTrack() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let script = """
            if application "Spotify" is running then
                tell application "Spotify" to next track
            else if application "Music" is running then
                tell application "Music" to next track
            end if
            """
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
            }
            self?.sendMediaKey(key: 18) // 18 is Next Track Key
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.updateNowPlaying()
            }
        }
    }
    
    func previousTrack() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let script = """
            if application "Spotify" is running then
                tell application "Spotify" to previous track
            else if application "Music" is running then
                tell application "Music" to previous track
            end if
            """
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
            }
            self?.sendMediaKey(key: 17) // 17 is Previous Track Key
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.updateNowPlaying()
            }
        }
    }
    
    private func sendMediaKey(key: Int32) {
        let src = CGEventSource(stateID: .hidSystemState)
        let evDown = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(key), keyDown: true)
        let evUp = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(key), keyDown: false)
        evDown?.post(tap: .cgSessionEventTap)
        evUp?.post(tap: .cgSessionEventTap)
    }
}
