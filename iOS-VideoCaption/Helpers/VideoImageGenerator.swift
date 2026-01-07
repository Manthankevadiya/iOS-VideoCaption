//
//  VideoImageGenerator.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 24/11/25.
//

import Foundation
import AVFoundation
import UIKit

struct VideoImageGenerator {
    
    // MARK: - Single Thumbnail Generation (Async)
    func generateThumbnail(from url: URL) async -> UIImage? {
        // This is a placeholder for your existing function, ensuring it works as expected.
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        // Use a time value of 0 for the first frame (main thumbnail)
        let time = CMTime(seconds: 0.0, preferredTimescale: 600)
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print("Error generating thumbnail: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Timeline Image Generation (New Function)
    /**
     Generates an array of UIImages from a video URL, taking a frame every 1.0 second.
     */
    func generateTimelineImages(from url: URL, interval: Double = 0.25) async -> [UIImage] {
        let asset = AVAsset(url: url)
        let durationSeconds = CMTimeGetSeconds(asset.duration)
        
        // 1. Generate and capture the very first frame synchronously (most reliable)
        var generatedImages: [UIImage] = []
        
        do {
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 200, height: 200)
            
            let time = CMTime(seconds: 0.0, preferredTimescale: 600)
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let firstImage = UIImage(cgImage: cgImage)
            generatedImages.append(firstImage)
        } catch {
            print("Error generating first frame synchronously: \(error.localizedDescription)")
            // If the first frame fails, add a placeholder or stop, but continue with placeholder for consistency
            let placeholder = UIImage(systemName: "photo.fill")?.withTintColor(.gray, renderingMode: .alwaysOriginal) ?? UIImage()
            generatedImages.append(placeholder)
        }
        
        // --- 2. Generate remaining time points asynchronously ---
        
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 200, height: 200)
        
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        
        var times: [NSValue] = []
        // ⭐ START at the first interval (1.0) since we handled 0.0 above.
        var currentTime: Double = interval
        let preferredTimescale: Int32 = 600
        
        // Loop to capture points at every 'interval' seconds.
        while currentTime < durationSeconds {
            
            let timeToCapture: Double
            
            if currentTime + interval >= durationSeconds {
                // This is the final segment: Capture a time point extremely close to the end.
                timeToCapture = durationSeconds - 0.001
            } else {
                // Regular segment: Capture the current time point.
                timeToCapture = currentTime
            }
            
            // Add the calculated time point
            let time = CMTime(seconds: timeToCapture, preferredTimescale: preferredTimescale)
            times.append(NSValue(time: time))
            
            // If we just added the final frame, exit the loop.
            if currentTime + interval >= durationSeconds {
                break
            }
            
            currentTime += interval
        }
        
        guard !times.isEmpty else {
            return generatedImages // Contains only the t=0 image
        }
        
        // 3. Kick off the asynchronous generation for the remaining frames
        let expectedAdditionalCount = times.count
        
        return await withCheckedContinuation { continuation in
            
            var processedCount = 0
            
            imageGenerator.generateCGImagesAsynchronously(forTimes: times) {
                (requestedTime, cgImage, actualTime, result, error) in
                
                DispatchQueue.main.async {
                    if result == .succeeded, let cgImage = cgImage {
                        let image = UIImage(cgImage: cgImage)
                        generatedImages.append(image)
                        
                    } else if result == .failed {
                        let placeholderImage = UIImage(systemName: "photo.fill")?.withTintColor(.gray, renderingMode: .alwaysOriginal) ?? UIImage()
                        generatedImages.append(placeholderImage)
                        print("❌ Timeline Image Generation FAILED for time \(requestedTime): \(error?.localizedDescription ?? "Unknown error")")
                    }
                    
                    processedCount += 1
                    
                    if processedCount == expectedAdditionalCount {
                        continuation.resume(returning: generatedImages)
                    }
                }
            }
        }
    }
}
