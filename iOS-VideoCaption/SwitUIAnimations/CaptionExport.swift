//
//  CaptionExport.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 08/12/25.
//

import UIKit
import SwiftUI
import AVFoundation
import Photos
import CoreImage

final class FrameByFrameExporter {
    
    // MARK: - Public Helper: Resolve URL
    static func resolveVideoURL(from path: String?) -> URL? {
        guard let path = path else { return nil }
        
        // 1. Check if absolute path
        if FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        
        // 2. Check Documents folder
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let docURL = documents.appendingPathComponent(path)
        
        if FileManager.default.fileExists(atPath: docURL.path) {
            return docURL
        }
        
        print("❌ Video not found for path: \(path)")
        return nil
    }
    
    // MARK: - Main Export Function
    static func export(
        config: ExportConfiguration,
        completion: @escaping (Bool, URL?, Error?) -> Void
    ) {
        let asset = AVURLAsset(url: config.videoURL)
        
        // Load tracks asynchronously
        asset.loadValuesAsynchronously(forKeys: ["tracks"]) {
            var error: NSError?
            guard asset.statusOfValue(forKey: "tracks", error: &error) == .loaded else {
                DispatchQueue.main.async { completion(false, nil, error) }
                return
            }
            
            guard let videoTrack = asset.tracks(withMediaType: .video).first else {
                let err = NSError(domain: "Exporter", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
                DispatchQueue.main.async { completion(false, nil, err) }
                return
            }
            
            // Calculate Video Properties
            let fps = videoTrack.nominalFrameRate > 0 ? Int32(videoTrack.nominalFrameRate) : 30
            let videoSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
            let renderSize = CGSize(width: abs(videoSize.width), height: abs(videoSize.height))
            
            DispatchQueue.main.async {
                do {
                    try runExportLoop(
                        asset: asset,
                        videoTrack: videoTrack,
                        size: renderSize,
                        config: config,
                        completion: completion
                    )
                } catch {
                    completion(false, nil, error)
                }
            }
        }
    }
    
    // MARK: - Private Implementation
    fileprivate static func runExportLoop(
        asset: AVAsset,
        videoTrack: AVAssetTrack,
        size: CGSize,
        config: ExportConfiguration,
        completion: @escaping (Bool, URL?, Error?) -> Void
    ) throws {
        
        // 1. Setup Reader (Video)
        let reader = try AVAssetReader(asset: asset)
        
        let videoSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: videoSettings)
        videoReaderOutput.alwaysCopiesSampleData = false
        if reader.canAdd(videoReaderOutput) { reader.add(videoReaderOutput) }
        
        // 1b. Setup Reader (Audio) - OPTIONAL
        var audioReaderOutput: AVAssetReaderTrackOutput?
        if let audioTrack = asset.tracks(withMediaType: .audio).first {
            print("🔊 Found Audio Track in source asset.")
            let decompressionAudioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM
            ]
            let audioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: decompressionAudioSettings)
            if reader.canAdd(audioOutput) {
                reader.add(audioOutput)
                audioReaderOutput = audioOutput
            } else {
                print("❌ Failed to add Audio Reader Output")
            }
        } else {
            print("⚠️ No Audio Track Found in source asset.")
        }
        
        // 2. Setup Writer
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("export_\(UUID().uuidString)")
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        
        // Video Input
        let bitrate = Int(size.width * size.height * 10)
        let videoCompressionProps: [String: Any] = [
            AVVideoAverageBitRateKey: bitrate,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
        ]
        let writerVideoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: videoCompressionProps
        ]
        
        let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: writerVideoSettings)
        videoWriterInput.expectsMediaDataInRealTime = false
        videoWriterInput.transform = videoTrack.preferredTransform
        
        let adaptorAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: adaptorAttributes)
        
        if writer.canAdd(videoWriterInput) { writer.add(videoWriterInput) }
        
        // Audio Input (Pass-through)
        var audioWriterInput: AVAssetWriterInput?
        if let _ = audioReaderOutput {
            let audioOutputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 44100,
                AVEncoderBitRateKey: 128000
            ]
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings)
            audioInput.expectsMediaDataInRealTime = false
            if writer.canAdd(audioInput) {
                writer.add(audioInput)
                audioWriterInput = audioInput
                print("✅ Audio Writer Input (AAC) added.")
            } else {
                print("❌ Failed to add Audio Writer Input")
            }
        }
        
        // 3. Start
        reader.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        // Scale & Frame Calculation (Same as before)
        let scaleRatio = size.width / config.referenceCanvasSize.width
        let scaledFontSize = config.fontSize * scaleRatio
        let scaledBorderWidth = config.borderWidth * scaleRatio
        
        let baseFrame = CGRect(
            x: config.uiCaptionFrame.origin.x * scaleRatio,
            y: config.uiCaptionFrame.origin.y * scaleRatio,
            width: config.uiCaptionFrame.width * scaleRatio,
            height: config.uiCaptionFrame.height * scaleRatio
        )
        
        // --- DESCENDER-SAFE PADDING ---
        // Add extra vertical padding so characters like "y", "g" are not cut.
        // You can tweak the factor (0.3) if needed.
        let verticalPadding = scaledFontSize * 0.3
        let paddedFrame = baseFrame.insetBy(dx: 0, dy: -verticalPadding)
        
        // 4. Setup SwiftUI Off-Screen Rendering
        let driver = AnimationDriver()
        var currentLineID: ObjectIdentifier?
        var currentLineStartTime: Double = 0
        
        // Helper to rebuild view in a padded container
        func rebuildHostView(for line: CaptionLine) -> (UIView, UIHostingController<AnimatedTextView>) {
            let relativeTimings = line.words.map { $0.startTime - line.startTime }
            let durations = line.words.map { $0.duration }
            driver.wordTimings = relativeTimings
            driver.wordDurations = durations
            currentLineStartTime = line.startTime
            
            let scaleFactor: CGFloat = 3.0
            let animationBufferPadding = scaledFontSize * 1.5
            
            let view = AnimatedTextView(
                text: line.text,
                style: config.style,
                wordDuration: config.defaultWordDuration,
                isDemo: false,
                wordFontName: config.fontName,
                fontSize: scaledFontSize,
                wordColor: Color(config.textColor),
                highlightColor: Color(config.highlightColor),
                borderWidth: scaledBorderWidth,
                borderColor: Color(config.borderColor),
                driver: driver
            )
            
            let host = UIHostingController(rootView: view)
            host.view.backgroundColor = .clear
            host.view.clipsToBounds = false
            host.view.layer.masksToBounds = false
            host.view.translatesAutoresizingMaskIntoConstraints = false
            
            let containerFrame = CGRect(
                x: 0,
                y: 0,
                width: paddedFrame.width + (animationBufferPadding * 2), // Add width buffer
                height: paddedFrame.height + (animationBufferPadding * 2) // Add height buffer
            )
            
            // Container view with padded size
            let container = UIView(frame: containerFrame)
            container.backgroundColor = .clear
            container.clipsToBounds = false
            container.layer.masksToBounds = false
            container.contentScaleFactor = scaleFactor
            
            container.addSubview(host.view)
            
            NSLayoutConstraint.activate([
                host.view.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                host.view.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                host.view.widthAnchor.constraint(lessThanOrEqualToConstant: paddedFrame.width * 1.5)
            ])
            
            container.layoutIfNeeded()
            
            return (container, host)
        }
        
        // Initial dummy host + container
        var host = UIHostingController(rootView: AnimatedTextView(
            text: "",
            style: config.style,
            wordDuration: 0.3,
            isDemo: false,
            wordFontName: config.fontName,
            fontSize: scaledFontSize,
            wordColor: .clear,
            highlightColor: .clear,
            borderWidth: 0,
            borderColor: .clear,
            driver: driver
        ))
        host.view.backgroundColor = .clear
        host.view.clipsToBounds = false
        host.view.layer.masksToBounds = false
        
        var hostContainer = UIView(frame: CGRect(origin: .zero, size: paddedFrame.size))
        hostContainer.backgroundColor = .clear
        hostContainer.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.centerXAnchor.constraint(equalTo: hostContainer.centerXAnchor),
            host.view.centerYAnchor.constraint(equalTo: hostContainer.centerYAnchor),
            host.view.widthAnchor.constraint(lessThanOrEqualToConstant: paddedFrame.width)
        ])
        hostContainer.layoutIfNeeded()
        
        // 5. Processing Queues
        let videoQueue = DispatchQueue(label: "video.export.queue")
        let ciContext = CIContext()
        
        // Use a DispatchGroup to wait for both Video and Audio to finish
        let processingGroup = DispatchGroup()
        processingGroup.enter()
        
        videoWriterInput.requestMediaDataWhenReady(on: videoQueue) {
            while videoWriterInput.isReadyForMoreMediaData {
                guard let sampleBuffer = videoReaderOutput.copyNextSampleBuffer() else {
                    videoWriterInput.markAsFinished()
                    processingGroup.leave()
                    return
                }
                
                guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { continue }
                let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                let seconds = CMTimeGetSeconds(presentationTime)
                
                // --- CAPTION LOGIC ---
                let formatter = config.captionFormatter
                let activeLine = formatter.captionLine(for: seconds)
                var overlayImage: UIImage?
                
                DispatchQueue.main.sync {
                    if let line = activeLine {
                        let lineID = ObjectIdentifier(line as AnyObject)
                        if lineID != currentLineID {
                            currentLineID = lineID
                            let (newContainer, newHost) = rebuildHostView(for: line)
                            hostContainer = newContainer
                            host = newHost
                        }
                        
                        let relativeTime = seconds - currentLineStartTime
                        driver.update(time: relativeTime)
                        
                        hostContainer.setNeedsLayout()
                        hostContainer.layoutIfNeeded()
                        
                        // ✅ 3. MATCH SCALES
                        let scaleFactor: CGFloat = 3.0
                        let format = UIGraphicsImageRendererFormat()
                        format.scale = scaleFactor
                        format.opaque = false

                        let renderer = UIGraphicsImageRenderer(bounds: hostContainer.bounds, format: format)
                        
                        // Use drawHierarchy for safety, backed by the contentScaleFactor we set earlier
                        overlayImage = renderer.image { _ in
                            hostContainer.drawHierarchy(in: hostContainer.bounds, afterScreenUpdates: true)
                        }
                    } else {
                        driver.update(time: 0)
                    }
                }
                
                // --- COMPOSITING ---
                var dstBuffer: CVPixelBuffer?
                if let pool = adaptor.pixelBufferPool {
                    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &dstBuffer)
                } else {
                    CVPixelBufferCreate(
                        nil,
                        Int(size.width),
                        Int(size.height),
                        kCVPixelFormatType_32BGRA,
                        nil,
                        &dstBuffer
                    )
                }
                
                if let dstPixelBuffer = dstBuffer {
                    CVPixelBufferLockBaseAddress(dstPixelBuffer, [])
                    
                    // Draw base video
                    let videoImage = CIImage(cvPixelBuffer: imageBuffer)
                    ciContext.render(videoImage, to: dstPixelBuffer)
                    
                    // Draw overlay (with padding-safe rect)
                    if let overlay = overlayImage,
                       let cgOverlay = overlay.cgImage,
                       let ctx = createCGContext(from: dstPixelBuffer) {
                        
                        let videoHeight = size.height
                        let originalBottomY = paddedFrame.origin.y + paddedFrame.height
                        let cgY = videoHeight - originalBottomY
                        let animationBufferPadding = scaledFontSize * 1.5
                        
                        // ✅ 4. PIXEL ALIGNMENT (Prevents blur)
                        // We calculate the rect, then apply .integral to snap to nearest pixel
                        let rawRect = CGRect(
                            x: paddedFrame.origin.x - animationBufferPadding,
                            y: cgY - animationBufferPadding,
                            width: paddedFrame.width + (animationBufferPadding * 2),
                            height: paddedFrame.height + (animationBufferPadding * 2)
                        )
                        let drawRect = rawRect.integral
                        
                        ctx.setShouldAntialias(true)
                        ctx.setAllowsAntialiasing(true)
                        ctx.interpolationQuality = .high
                        
                        ctx.draw(cgOverlay, in: drawRect)
                    }
                    
                    CVPixelBufferUnlockBaseAddress(dstPixelBuffer, [])
                    adaptor.append(dstPixelBuffer, withPresentationTime: presentationTime)
                }
            }
        }
        
        // --- AUDIO EXPORT LOOP ---
        if let audioInput = audioWriterInput, let audioOutput = audioReaderOutput {
            print("⏳ Audio processing started...")
            processingGroup.enter()
            
            let audioSerialQueue = DispatchQueue(label: "audio.export.serial")
            
            audioInput.requestMediaDataWhenReady(on: audioSerialQueue) {
                while audioInput.isReadyForMoreMediaData {
                    guard let sampleBuffer = audioOutput.copyNextSampleBuffer() else {
                        print("✅ Audio processing finished.")
                        audioInput.markAsFinished()
                        processingGroup.leave()
                        return
                    }
                    
                    if !audioInput.append(sampleBuffer) {
                        print("❌ Audio Append Failed: \(writer.error?.localizedDescription ?? "Unknown error")")
                        audioInput.markAsFinished()
                        processingGroup.leave()
                        return
                    }
                }
            }
        }
        
        processingGroup.notify(queue: .main) {
            writer.finishWriting {
                reader.cancelReading()
                DispatchQueue.main.async {
                    if writer.status == .completed {
                        let fileSize = (try? Data(contentsOf: outputURL).count) ?? 0
                        print("✅ Writer completed. Size: \(fileSize) bytes")
                        
                        saveVideoToGallery(url: outputURL) { success, error in
                            if success {
                                completion(true, outputURL, nil)
                            } else {
                                completion(false, nil, error)
                            }
                        }
                    } else {
                        print("❌ Writer failed: \(writer.error?.localizedDescription ?? "Unknown")")
                        completion(false, nil, writer.error)
                    }
                }
            }
        }
    }
    
    // Helper to create CGContext from CVPixelBuffer
    static func createCGContext(from pixelBuffer: CVPixelBuffer) -> CGContext? {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        
        return CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )
    }
    
    static func saveVideoToGallery(url: URL, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                completion(false, NSError(domain: "Exporter", code: -10, userInfo: [NSLocalizedDescriptionKey: "Photo Lib Access Denied"]))
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { success, error in
                completion(success, error)
            }
        }
    }
}
