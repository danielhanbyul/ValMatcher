//
//  PreloadedVideoPlayerView.swift
//  ValMatcher
//
//  Created by Daniel Han on 1/12/25.
//

import SwiftUI
import AVKit

/// A View that shows a preloaded AVPlayer and toggles fullscreen for horizontal videos.
struct PreloadedVideoPlayerView: View {
    /// The preloaded, ready-to-play AVPlayer
    let player: AVPlayer
    
    /// The original video URL, used for orientation checks
    let url: URL
    
    @State private var isHorizontalVideo = false
    @State private var showFullScreenPlayer = false

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                VideoPlayer(player: player)
                    .scaleEffect(calculateScale(geometry: geometry))
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .onAppear {
                        checkVideoOrientation()
                        // Autoplay on appear
                        player.seek(to: .zero)
                        player.play()
                        addReplayObserver()
                    }
                    .onDisappear {
                        player.pause()
                    }
                    .onTapGesture {
                        if isHorizontalVideo {
                            // For horizontal videos, go fullscreen
                            showFullScreenPlayer = true
                        } else {
                            // For vertical videos, toggle play/pause
                            if player.timeControlStatus == .playing {
                                player.pause()
                            } else {
                                player.play()
                            }
                        }
                    }
            }
        }
        // Full-screen cover for horizontal orientation
        .fullScreenCover(isPresented: $showFullScreenPlayer) {
            FullScreenVideoPlayer(url: url, isHorizontalVideo: isHorizontalVideo)
        }
    }
    
    // MARK: - Orientation, Replay, Scaling

    private func checkVideoOrientation() {
        let asset = AVAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else { return }
        let dimensions = track.naturalSize.applying(track.preferredTransform)
        isHorizontalVideo = abs(dimensions.width) > abs(dimensions.height)
    }

    private func addReplayObserver() {
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
        return baseScale * 1.15 // Slight zoom
    }
}
