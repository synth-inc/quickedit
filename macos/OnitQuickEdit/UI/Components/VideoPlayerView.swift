//
//  VideoPlayerView.swift
//  Onit
//
//  Created by Loyd Kim on 11/19/25.
//

import AVKit
import SwiftUI

struct VideoPlayerView: NSViewRepresentable {
    // MARK: - Properties
    
    private let videoAssetName: String
    private let fileExtension: String
    private let controlsStyle: AVPlayerViewControlsStyle
    private let videoGravity: AVLayerVideoGravity
    private let shouldLoop: Bool
    
    // MARK: - Initializer
    
    init(
        videoAssetName: String,
        fileExtension: String = "mp4",
        controlsStyle: AVPlayerViewControlsStyle = .none,
        videoGravity: AVLayerVideoGravity = .resizeAspect,
        shouldLoop: Bool = true
    ) {
        self.videoAssetName = videoAssetName
        self.fileExtension = fileExtension
        self.controlsStyle = controlsStyle
        self.videoGravity = videoGravity
        self.shouldLoop = shouldLoop
    }
    
    // MARK: - Protocol Conformance

    func makeCoordinator() -> Coordinator {
        Self.Coordinator(shouldLoop: self.shouldLoop)
    }

    func makeNSView(context: Self.Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        
        playerView.controlsStyle = self.controlsStyle
        playerView.videoGravity = self.videoGravity
        
        if let player = context.coordinator.player(
            for: videoAssetName,
            as: self.fileExtension
        ) {
            playerView.player = player
        }
        
        return playerView
    }

    func updateNSView(
        _ playerView: AVPlayerView,
        context: Self.Context
    ) {
        guard let player = context.coordinator.player(
            for: videoAssetName,
            as: self.fileExtension
        )
        else {
            playerView.player = nil
            return
        }
        
        /// Only swap player if the cached asset changed.
        if playerView.player !== player {
            playerView.player = player
        }
    }
    
    // MARK: - Coordinator

    final class Coordinator {
        private let shouldLoop: Bool
        
        init(shouldLoop: Bool) {
            self.shouldLoop = shouldLoop
        }
        
        deinit {
            for observer in self.observers.values {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        
        typealias VideoAssetName = String
        
        private var cachedPlayers: [VideoAssetName: AVPlayer] = [:]
        private var observers: [VideoAssetName: NSObjectProtocol] = [:]
        
        func player(
            for videoAssetName: VideoAssetName,
            as fileExtension: String
        ) -> AVPlayer? {
            if let existingPlayer = self.cachedPlayers[videoAssetName] {
                return existingPlayer
            }
            
            guard let videoDataAsset = NSDataAsset(name: videoAssetName)
            else {
                return nil
            }
            
            let temporaryUrl = self.getTemporaryUrl(
                for: videoAssetName,
                as: fileExtension
            )
            
            let cachedFileNotYetCreated = !FileManager.default.fileExists(
                atPath: temporaryUrl.path
            )
            
            if cachedFileNotYetCreated {
                do {
                    /// We're writing to the macOS temporary directory, which is automatically cleaned up periodically (e.g. on reboot, when system needs space, etc.), so there are no concerns with caching video files.
                    try videoDataAsset.data.write(
                        to: temporaryUrl,
                        options: .atomic
                    )
                } catch {
                    return nil
                }
            }
            
            let playerItem = AVPlayerItem(url: temporaryUrl)
            let player = AVPlayer(playerItem: playerItem)
            
            player.actionAtItemEnd = .none

            if self.shouldLoop {
                let observer = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: playerItem,
                    queue: .main
                ) { _ in
                    player.seek(to: .zero)
                    player.play()
                }
                
                self.observers[videoAssetName] = observer
            }

            player.play()
            self.cachedPlayers[videoAssetName] = player
            
            return player
        }
        
        private func getTemporaryUrl(
            for assetName: String,
            as fileExtension: String
        ) -> URL {
            let normalizedExtension = fileExtension.hasPrefix(".") ? fileExtension : ".\(fileExtension)"
            
            return FileManager
                .default
                .temporaryDirectory
                .appendingPathComponent("onit-video-\(assetName)\(normalizedExtension)")
        }
    }
}
