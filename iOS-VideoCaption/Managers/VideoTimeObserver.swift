//
//  VideoTimeObserver.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 05/12/25.
//

import AVFoundation
import CoreMedia
import UIKit

/**
 Manages the synchronization between an AVPlayer's time and provides updates via a closure.
 */
class VideoTimeObserver: NSObject {
    
    let player: AVPlayer
    private var timeObserverToken: Any?
    private let timeUpdateHandler: (Double) -> Void
    
    init(player: AVPlayer, updateHandler: @escaping (Double) -> Void) {
        self.player = player
        self.timeUpdateHandler = updateHandler
        super.init()
        setupTimeObserver()
    }
    
    deinit {
        // Essential: Clean up the observer token when the object is released.
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
    
    private func setupTimeObserver() {
        // Update 30 times per second
        let interval = CMTime(value: 1, timescale: 30)
        
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let currentTimeInSeconds = CMTimeGetSeconds(time)
            self.timeUpdateHandler(currentTimeInSeconds)
        }
    }
}
