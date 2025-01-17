//
//  PreloadedVideoPlayerView.swift
//  ValMatcher
//
//  Created by Daniel Han on 1/12/25.
//

import SwiftUI
import AVKit

struct PreloadedVideoPlayerView: View {
    @State private var player: AVPlayer?
    let url: URL
    
    @State private var isHorizontalVideo = false
    @State private var isVideoReady = false
    @State private var showFullScreenPlayer = false
    
    /// Whether we *want* to play the video right now
    /// This is controlled externally by the parent view
    let shouldPlay: Bool
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                Group {
                    if let player = player, isVideoReady {
                        VideoPlayer(player: player)
                            .scaleEffect(calculateScale(geometry: geometry))
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .onAppear {
                                // If the parent says “play now”, do so
                                if shouldPlay {
                                    startVideoPlayback()
                                }
                            }
                            .onChange(of: shouldPlay) { newValue in
                                if newValue {
                                    startVideoPlayback()
                                } else {
                                    stopVideoPlayback()
                                }
                            }
                            .onDisappear {
                                stopVideoPlayback()
                            }
                            .onTapGesture {
                                handleTapGesture()
                            }
                    } else {
                        // Placeholder while loading
                        Color.black
                            .overlay(
                                ProgressView("Loading...")
                                    .foregroundColor(.white)
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .cornerRadius(20)
                            .onAppear {
                                preloadVideo()
                            }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showFullScreenPlayer) {
            if let player = player {
                FullScreenVideoPlayer(url: url, isHorizontalVideo: isHorizontalVideo)
            }
        }
    }
    
    // MARK: - Preload
    
    private func preloadVideo() {
        // Preload the video asynchronously
        Task {
            let asset = AVAsset(url: url)
            let requiredKeys = ["playable"]
            
            do {
                try await asset.loadValues(forKeys: requiredKeys)
                DispatchQueue.main.async {
                    self.player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
                    self.isVideoReady = true
                    checkVideoOrientation()
                }
            } catch {
                print("Error preloading video for URL \(url): \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Playback Control
    
    private func startVideoPlayback() {
        guard let player = player else { return }
        player.seek(to: .zero)
        player.play()
        addReplayObserver(to: player)
    }
    
    private func stopVideoPlayback() {
        guard let player = player else { return }
        player.pause()
        player.seek(to: .zero)
    }
    
    private func handleTapGesture() {
        guard let player = player else { return }
        if isHorizontalVideo {
            player.pause()
            showFullScreenPlayer = true
        } else {
            if player.timeControlStatus == .playing {
                player.pause()
            } else {
                player.play()
            }
        }
    }
    
    // MARK: - Orientation & Replay
    
    private func checkVideoOrientation() {
        guard let track = AVAsset(url: url).tracks(withMediaType: .video).first else { return }
        let dimensions = track.naturalSize.applying(track.preferredTransform)
        isHorizontalVideo = abs(dimensions.width) > abs(dimensions.height)
    }
    
    private func addReplayObserver(to player: AVPlayer) {
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
    }
    
    private func calculateScale(geometry: GeometryProxy) -> CGFloat {
        let videoAspectRatio = isHorizontalVideo ? 16.0 / 9.0 : 9.0 / 16.0
        let viewAspectRatio = geometry.size.width / geometry.size.height
        let baseScale = max(viewAspectRatio / videoAspectRatio, 1.0)
        return baseScale * 1.15
    }
}
