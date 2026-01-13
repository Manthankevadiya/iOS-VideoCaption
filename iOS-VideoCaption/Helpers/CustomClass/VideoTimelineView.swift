//
//  VideoTimelineView.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 24/11/25.
//

import UIKit
import AVFoundation
import CoreData

protocol VideoTimelineViewDelegate: AnyObject {
    func videoTimelineView(_ timelineView: VideoTimelineView, didScrubTo time: CMTime)
    func videoTimelineViewDidEndScrubbing(_ timelineView: VideoTimelineView)
    func timelineDidToggleMute(isMuted: Bool)
    func videoTimelineDidRequestRenameWord(at index: Int,currentText: String,objectID: NSManagedObjectID?)
}

class VideoTimelineView: UIView {
    
    // MARK: - Properties
    weak var delegate: VideoTimelineViewDelegate?
    private let timeRulerView = TimeRulerView()
    private var videoAsset: AVAsset?
    private var imageGenerator: AVAssetImageGenerator?
    
    // UI Elements
    private let collectionView: UICollectionView
    private let playheadView = UIView() // The yellow line
    private let currentTimeLabel = PaddedLabel()
    private let totalDurationButton = UIButton(type: .custom)
    
    let coreDataManager = CoreDataManager.shared
    var project: CaptionEntity!
    
    private let wordCollectionView: UICollectionView
    private var wordSegments: [WordSegment] = []
    private var selectedWordIndex: Int?
    private let wordTimelineLayout = WordTimelineLayout()
    
    private var isMuted: Bool = false {
        didSet {
            // Update the button appearance when the state changes
            if let buttonView = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: 0)) as? VolumeButtonView {
                buttonView.updateMuteState(isMuted: isMuted)
            }
        }
    }
    
    private let segmentDuration: Double = 0.25 // 0.5s per thumbnail cell
    private let standardThumbnailWidth: CGFloat = 60
    private let thumbnailHeight: CGFloat = 45.0
    private let volumeButtonWidth: CGFloat = 50.0
    
    private var thumbnails: [UIImage] = []
    private var thumbnailTimes: [CMTime] = []
    private var totalVideoDuration: CMTime = .zero
    
    private let majorMarkerInterval: Double = 0.25
    
    private var minContentOffsetX: CGFloat {
        let playheadOffset = bounds.width / 2
        let positionOfZeroSeconds = volumeButtonWidth
        
        return positionOfZeroSeconds - playheadOffset
    }
    
    private var maxContentOffsetX: CGFloat {
        let totalContentWidth = calculateContentLayoutWidth()
        let playheadOffset = bounds.width / 2
        
        return totalContentWidth - playheadOffset
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        wordCollectionView = UICollectionView(frame: .zero, collectionViewLayout: wordTimelineLayout)
        super.init(frame: frame)
        
        setupUI()
        setupCollectionView()
        setupWordCollectionView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        guard bounds.width > 0 else { return }
        let horizontalPadding = bounds.width / 2
        
        if collectionView.contentInset.left != horizontalPadding {
            collectionView.contentInset = UIEdgeInsets(top: 0, left: horizontalPadding, bottom: 0, right: horizontalPadding)
        }
        
        // Ensure word collection view matches exactly
        if wordCollectionView.contentInset.left != horizontalPadding {
            wordCollectionView.contentInset = UIEdgeInsets(top: 0, left: horizontalPadding, bottom: 0, right: horizontalPadding)
        }
        
        print("📏 Thumbnails Height: $$collectionView.frame.height)")
    }
    
    func updatePlayhead(to time: CMTime) {
        guard totalVideoDuration.seconds > 0, bounds.width > 0 else { return }
        
        self.updateTimeLabel(to: time)
        
        // --- Scroll Position Logic Remains the Same ---
        let contentLayoutWidth = calculateContentLayoutWidth()
        let timeContentWidth = contentLayoutWidth - volumeButtonWidth
        
        let playheadOffset = bounds.width / 2
        let horizontalPadding = playheadOffset
        
        if collectionView.contentInset.left != horizontalPadding {
            collectionView.contentInset = UIEdgeInsets(top: 0, left: horizontalPadding, bottom: 0, right: horizontalPadding)
        }
        
        // Calculate Scroll Position
        let scrollFraction = time.seconds / totalVideoDuration.seconds
        let targetContentX = (timeContentWidth * scrollFraction) + volumeButtonWidth
        
        let newContentOffsetX = targetContentX - horizontalPadding
        let finalContentOffsetX = max(newContentOffsetX, minContentOffsetX)
        
        collectionView.setContentOffset(CGPoint(x: finalContentOffsetX, y: 0), animated: false)
        wordCollectionView.contentOffset.x = finalContentOffsetX
        
        timeRulerView.transform = CGAffineTransform(translationX: -finalContentOffsetX, y: 0)
        updateActiveWord(at: time.seconds)
    }
    
    private func setupWordCollectionView() {
        wordCollectionView.register(WordCvCell.self, forCellWithReuseIdentifier: WordCvCell.reuse)
        wordCollectionView.dataSource = self
        wordCollectionView.delegate = self
        wordCollectionView.backgroundColor = .clear
        wordCollectionView.showsHorizontalScrollIndicator = false
        wordCollectionView.contentInsetAdjustmentBehavior = .never
    }
    
    func setWordSegments(_ segments: [WordSegment]) {
        self.wordSegments = segments
        
        // Update custom layout
        wordTimelineLayout.segments = segments
        wordTimelineLayout.pointsPerSecond = standardThumbnailWidth / CGFloat(segmentDuration)
        wordTimelineLayout.leadingOffset = volumeButtonWidth
        
        wordCollectionView.reloadData()
        wordCollectionView.collectionViewLayout.invalidateLayout()
    }
    
    private func handleWordRename(at index: Int, newText: String) {
        guard index < wordSegments.count else { return }
        
        wordSegments[index].text = newText
        delegate?.videoTimelineDidRequestRenameWord(at: index, currentText: newText, objectID: wordSegments[index].objectID)
        wordCollectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
    }
    
    // MARK: - Setup UI
    private func setupUI() {
        
        // Main container setup
        clipsToBounds = true // Crucial for containing the internal views
        
        // --- 1. Add Subviews ---
        addSubview(timeRulerView)
        addSubview(wordCollectionView)
        addSubview(collectionView)
        addSubview(playheadView)
        addSubview(currentTimeLabel)
        addSubview(totalDurationButton)
        
        // --- 2. Styling ---
        
        totalDurationButton.backgroundColor = UIColor(white: 0.1, alpha: 0.9) // Dark background container
        totalDurationButton.layer.cornerRadius = 4
        totalDurationButton.layer.borderWidth = 1
        totalDurationButton.layer.borderColor = UIColor.darkGray.cgColor
        totalDurationButton.setTitleColor(.lightGray, for: .normal)
        totalDurationButton.titleLabel?.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        // Add padding inside the button
        totalDurationButton.contentEdgeInsets = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
        
        // Add Target Action
        totalDurationButton.addTarget(self, action: #selector(didTapTotalDuration), for: .touchUpInside)
        
        // Time Ruler
        timeRulerView.backgroundColor = .clear
        
        // Collection View Styling (Thumbnail Strip)
        collectionView.backgroundColor = .clear
        collectionView.layer.cornerRadius = 8
        collectionView.clipsToBounds = true    // Ensures rounding is visible
        
        // Playhead Styling
        playheadView.backgroundColor = .yellow
        playheadView.layer.cornerRadius = 2    // Rounded line effect (half width)
        playheadView.clipsToBounds = true      // Essential for cornerRadius to work on a line
        
        // Current Time Label Styling
        currentTimeLabel.backgroundColor = UIColor.color141414
        currentTimeLabel.textColor = .white
        currentTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        currentTimeLabel.textAlignment = .center
        currentTimeLabel.layer.cornerRadius = 4
        currentTimeLabel.clipsToBounds = true
        
        // --- 3. Constraints ---
        timeRulerView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        playheadView.translatesAutoresizingMaskIntoConstraints = false
        currentTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        totalDurationButton.translatesAutoresizingMaskIntoConstraints = false
        wordCollectionView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Time Ruler View (Top part for 0s, 2s, 4s markers)
            timeRulerView.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            timeRulerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            timeRulerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            timeRulerView.heightAnchor.constraint(equalToConstant: 20),
            
            // Total Duration Button (Top Right)
            totalDurationButton.topAnchor.constraint(equalTo: topAnchor, constant: 0),
            totalDurationButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            totalDurationButton.heightAnchor.constraint(equalToConstant: 20),
            
            // Current Time Label (Below Ruler)
            currentTimeLabel.bottomAnchor.constraint(equalTo: collectionView.topAnchor, constant: 0),
            currentTimeLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            currentTimeLabel.heightAnchor.constraint(equalToConstant: 20),
            currentTimeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),
            
            // Thumbnail Collection View (Middle - Below Label)
            collectionView.topAnchor.constraint(equalTo: timeRulerView.bottomAnchor, constant: 25),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 60), // Pin to the bottom of the container
            
            // Word Collection View (Bottom - Below Thumbnails)
            wordCollectionView.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 0),
            wordCollectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            wordCollectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            wordCollectionView.heightAnchor.constraint(equalToConstant: 35),
            
            // Playhead View (Spans from Thumbnails down to Words)
            playheadView.widthAnchor.constraint(equalToConstant: 4),
            playheadView.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),
            playheadView.heightAnchor.constraint(equalToConstant: 50),
            playheadView.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
        
        bringSubviewToFront(currentTimeLabel)
        bringSubviewToFront(totalDurationButton)
    }
    
    private func setupCollectionView() {
        collectionView.register(ThumbnailCell.self, forCellWithReuseIdentifier: ThumbnailCell.reuseIdentifier)
        collectionView.register(VolumeButtonView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: VolumeButtonView.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never
    }
    
    // MARK: - Public Methods
    func configure(with asset: AVAsset) {
        self.videoAsset = asset
        self.totalVideoDuration = asset.duration
        self.imageGenerator = AVAssetImageGenerator(asset: asset)
        self.imageGenerator?.appliesPreferredTrackTransform = true
        self.imageGenerator?.requestedTimeToleranceBefore = .zero
        self.imageGenerator?.requestedTimeToleranceAfter = .zero
        self.imageGenerator?.apertureMode = .cleanAperture
        
        let totalSeconds = CMTimeGetSeconds(asset.duration)
        totalDurationButton.setTitle(format(time: asset.duration), for: .normal)
        currentTimeLabel.text = format(time: .zero)
        
        layoutIfNeeded()
        
        timeRulerView.setupRuler(totalDurationSeconds: totalSeconds, thumbnailWidth: standardThumbnailWidth, segmentDuration: segmentDuration, leadingOffset: volumeButtonWidth)
        loadThumbnailsFromCoreData()
    }
    
    private func widthForItems(upTo index: Int) -> CGFloat {
        guard index > 0 else { return 0.0 }
        
        let totalSeconds = totalVideoDuration.seconds
        let segmentDuration = self.segmentDuration // Use instance property (0.5)
        let standardWidth = standardThumbnailWidth
        
        let totalSegmentsCount = Int(ceil(totalSeconds / segmentDuration))
        var cumulativeWidth: CGFloat = 0.0
        
        for i in 0..<index {
            if i < totalSegmentsCount - 1 {
                cumulativeWidth += standardWidth
            } else if i == totalSegmentsCount - 1 {
                let remainingDuration = totalSeconds.truncatingRemainder(dividingBy: segmentDuration)
                if remainingDuration > 0.01 {
                    let dynamicWidth = CGFloat(remainingDuration / segmentDuration) * standardWidth
                    cumulativeWidth += max(dynamicWidth, 10.0)
                } else {
                    cumulativeWidth += standardWidth
                }
            }
        }
        return cumulativeWidth
    }
    
    func updateActiveWord(at time: Double) {
        // 1. Find the index of the word that contains the current time
        // We look for a word where: startTime <= currentTime < endTime
        if let index = wordSegments.firstIndex(where: { time >= $0.start && time < $0.end }) {
            
            // Only update if the index actually changed to avoid unnecessary reloads
            if selectedWordIndex != index {
                let oldIndex = selectedWordIndex
                selectedWordIndex = index
                
                // 2. Reload strictly the affected cells to show/hide border
                var indexPathsToReload: [IndexPath] = [IndexPath(item: index, section: 0)]
                if let old = oldIndex {
                    indexPathsToReload.append(IndexPath(item: old, section: 0))
                }
                
                // Perform batch update or simple reload
                wordCollectionView.reloadItems(at: indexPathsToReload)
                
                // Optional: Ensure the active word is visible (if you were scrolling word list separately)
                // Since word list is locked to thumbnail scroll, 'updatePlayhead' usually handles the scroll.
                // But if you want to be extra safe:
                // wordCollectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredHorizontally, animated: true)
            }
        } else {
            // If no word is active (e.g. silence gap), clear selection
            if selectedWordIndex != nil {
                let oldIndex = selectedWordIndex
                selectedWordIndex = nil
                if let old = oldIndex {
                    wordCollectionView.reloadItems(at: [IndexPath(item: old, section: 0)])
                }
            }
        }
    }
    
    // MARK: - Helper
    private func format(time: CMTime) -> String {
        let currentSeconds = CMTimeGetSeconds(time)
        let totalDurationSeconds = CMTimeGetSeconds(totalVideoDuration)
        
        // Safety check
        guard currentSeconds.isFinite, currentSeconds >= 0 else {
            // Return default zero strings based on total duration scope
            if totalDurationSeconds >= 3600 { return "00:00:00:00" }
            if totalDurationSeconds >= 60 { return "00:00:00" }
            return "00:00"
        }
        
        // 1. Calculate components
        let totalSecInt = Int(currentSeconds)
        let hours = totalSecInt / 3600
        let minutes = (totalSecInt % 3600) / 60
        let seconds = totalSecInt % 60
        
        // Calculate 2-digit Milliseconds/Centiseconds
        let fraction = currentSeconds - Double(totalSecInt)
        let centiseconds = Int(fraction * 100)
        
        // 2. Determine Format based on TOTAL duration (not current time)
        
        if totalDurationSeconds >= 3600 {
            // Case 1: Video is 1 hour or longer -> Show HH:MM:SS:mm
            return String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, centiseconds)
            
        } else if totalDurationSeconds >= 60 {
            // Case 2: Video is 1 min to 59 min -> Show MM:SS:mm (Hide HH)
            return String(format: "%02d:%02d:%02d", minutes, seconds, centiseconds)
            
        } else {
            // Case 3: Video is less than 1 min -> Show SS:mm (Hide HH and MM)
            return String(format: "%02d:%02d", seconds, centiseconds)
        }
    }
    
    @objc private func didTapTotalDuration() {
        guard totalVideoDuration.seconds > 0 else { return }
        
        // Seek to exactly the end
        let endTime = totalVideoDuration
        
        updatePlayhead(to: endTime)
        updateTimeLabel(to: endTime)
        
        // Notify Delegate
        delegate?.videoTimelineView(self, didScrubTo: endTime)
    }
    
    func calculateContentLayoutWidth() -> CGFloat {
        let numberOfThumbnails = collectionView.numberOfItems(inSection: 0)
        var width: CGFloat = volumeButtonWidth // Start with header/button width
        
        guard numberOfThumbnails > 0 else { return volumeButtonWidth }
        
        // ⭐ CRITICAL: Iterate through all items and get the actual, calculated size.
        for i in 0..<numberOfThumbnails {
            let indexPath = IndexPath(item: i, section: 0)
            
            // This line calls the UICollectionViewDelegateFlowLayout method you provided
            let size = collectionView(collectionView,
                                      layout: collectionView.collectionViewLayout,
                                      sizeForItemAt: indexPath)
            width += size.width
        }
        
        // Since there's no inter-item spacing, this sum is the accurate total content width.
        return width
    }
    
    private func updateScrubTime() {
        guard totalVideoDuration.seconds > 0 else { return }
        
        let durationSeconds = totalVideoDuration.seconds
        let preferredTimescale = totalVideoDuration.timescale
        
        // 1. Calculate Raw Time based on Physical Scroll Position
        // We use the exact same width used for layout
        let timeContentWidth = calculateContentLayoutWidth() - volumeButtonWidth
        guard timeContentWidth > 0 else { return }
        
        let offsetX = collectionView.contentOffset.x
        
        // 0.0s is located at volumeButtonWidth
        let minOffset = volumeButtonWidth - (bounds.width / 2.0)
        
        let scrollDistance = offsetX - minOffset
        
        // Map distance to time
        let rawScrubTimeSeconds = durationSeconds * (scrollDistance / timeContentWidth)
        
        // ⭐ FIX: Clamp strictly between 0 and Total Duration.
        // Removed 'universalSafeTolerance' subtraction so you can reach the end.
        let finalScrubSeconds = max(0.0, min(rawScrubTimeSeconds, durationSeconds))
        
        let rawScrubTime = CMTime(seconds: finalScrubSeconds, preferredTimescale: preferredTimescale)
        
        // 3. Update UI
        currentTimeLabel.text = format(time: rawScrubTime)
        updateActiveWord(at: finalScrubSeconds)
        
        delegate?.videoTimelineView(self, didScrubTo: rawScrubTime)
    }
    
    private func contentOffset(forTime time: CMTime) -> CGFloat {
        let timeSeconds = CMTimeGetSeconds(time)
        
        // ⭐ CRITICAL CONSTANTS - Adjust these if they are different in your project!
        let standardThumbnailWidth: CGFloat = standardThumbnailWidth
        let segmentDuration: Double = segmentDuration // Usually 1.0 second per thumbnail
        
        // Calculate the total horizontal distance the video content covers
        // (Time in seconds / segment duration) * Width per segment
        let distanceTraveled = CGFloat(timeSeconds / segmentDuration) * standardThumbnailWidth
        
        // The final offset is: Distance Traveled + Initial Offset (Volume Button) - Center Playhead Offset
        let playheadOffset = bounds.width / 2.0
        let targetOffset = distanceTraveled + volumeButtonWidth - playheadOffset
        
        return targetOffset
    }
    
    func updateTimeLabel(to time: CMTime) {
        self.currentTimeLabel.text = format(time: time)
    }
    
    @objc func didTapVolumeButton() {
        isMuted.toggle()
        delegate?.timelineDidToggleMute(isMuted: isMuted)
    }
    
    // MARK: - Thumbnail Generation
    private func loadThumbnailsFromCoreData() {
        let fetchedImages = self.coreDataManager.fetchTimelineImages(for: self.project)
        let expectedCount = Int(ceil(self.project.totalDuration / segmentDuration))
        
        if fetchedImages.count < (expectedCount / 2) {
            print("⚠️ Detected stale thumbnail cache. Regenerating for 0.5s resolution...")
        }
        
        self.thumbnails = fetchedImages
        
        let duration = self.project.totalDuration
        
        if duration > 0 {
            // Using updated 0.5s duration
            let framesPerSecond = self.segmentDuration
            let preferredTimescale: Int32 = 600
            
            self.thumbnailTimes = self.thumbnails.enumerated().map { (index, _) in
                let timeSeconds = Double(index) * framesPerSecond
                let clampedTime = min(timeSeconds, duration - 0.001)
                return CMTime(seconds: clampedTime, preferredTimescale: preferredTimescale)
            }
        } else {
            self.thumbnailTimes = []
        }
        
        DispatchQueue.main.async {
            self.collectionView.reloadData()
            self.collectionView.layoutIfNeeded()
            self.updatePlayhead(to: .zero)
        }
    }
    
    private func getDynamicLastThumbnailWidth() -> CGFloat {
        // These constants must match what you use in your layout logic (e.g., sizeForItemAt)
        let standardThumbnailWidth: CGFloat = standardThumbnailWidth
        let framesPerSecond: Double = segmentDuration
        
        let totalSeconds = CMTimeGetSeconds(totalVideoDuration)
        let numberOfThumbnails = collectionView.numberOfItems(inSection: 0)
        
        // Safety check: ensure there is at least one item
        guard numberOfThumbnails > 0 else { return 0 }
        
        // Check if the video duration is exactly divisible by the segment length
        let isLastSegmentPartial = totalSeconds.truncatingRemainder(dividingBy: framesPerSecond) != 0.0
        
        if isLastSegmentPartial {
            // Calculate the time covered by the full (N-1) frames
            let timeCoveredByFullFrames = Double(numberOfThumbnails - 1) * framesPerSecond
            
            // Calculate the time remaining for the last frame
            let remainingTime = totalSeconds - timeCoveredByFullFrames
            
            // The width of the last cell is proportional to the remaining time
            let dynamicWidth = remainingTime * standardThumbnailWidth
            
            // Return a positive width, using 1.0 as the absolute minimum width
            return max(1.0, dynamicWidth)
        } else {
            // If the last segment is exactly 1.0s, use the standard width.
            return standardThumbnailWidth
        }
    }
    
}

extension VideoTimelineView: UICollectionViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        var offsetX = scrollView.contentOffset.x
        
        // Bounds Checking
        if offsetX < minContentOffsetX { offsetX = minContentOffsetX; scrollView.contentOffset.x = minContentOffsetX }
        let safeMax = maxContentOffsetX
        if offsetX > safeMax { offsetX = safeMax; scrollView.contentOffset.x = safeMax }
        
        if scrollView == collectionView {
            // Thumbnail scrolled -> Sync Word List
            wordCollectionView.contentOffset.x = offsetX
        } else if scrollView == wordCollectionView {
            // Word List scrolled -> Sync Thumbnails
            collectionView.contentOffset.x = offsetX
        }
        
        
        timeRulerView.transform = CGAffineTransform(translationX: -offsetX, y: 0)
        
        if scrollView.isDragging || scrollView.isDecelerating {
            updateScrubTime()
        }
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if scrollView == collectionView {
            
            let playheadOffset = bounds.width / 2
            let horizontalPadding = playheadOffset
            
            // The 0.0s mark is located exactly after the volume button's width.
            let positionOfZeroSeconds = volumeButtonWidth
            
            // The minimum required Content Offset (x) to center the 0.0s mark under the playhead:
            let minContentOffsetX = positionOfZeroSeconds - horizontalPadding
            
            // 2. Check if the proposed scroll position is too far left.
            if targetContentOffset.pointee.x < minContentOffsetX {
                targetContentOffset.pointee.x = minContentOffsetX
            }
            
            if targetContentOffset.pointee.x > maxContentOffsetX {
                targetContentOffset.pointee.x = maxContentOffsetX
            }
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            // Final check and scrub if user lifts finger without deceleration
            updateScrubTime()
            delegate?.videoTimelineViewDidEndScrubbing(self)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // Final check and scrub after deceleration stops
        updateScrubTime()
        delegate?.videoTimelineViewDidEndScrubbing(self)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        // --- Word Collection View Tap Logic ---
        if collectionView == wordCollectionView {
            let segment = wordSegments[indexPath.item]
            
            // 🔹 FIX: If already selected, trigger the RENAME POPUP via delegate
            // This prevents the cell's internal keyboard from opening.
            if selectedWordIndex == indexPath.item {
                delegate?.videoTimelineDidRequestRenameWord(
                    at: indexPath.item,
                    currentText: segment.text,
                    objectID: segment.objectID
                )
                return
            }
            
            // If not selected, select it and scrub the video to that word's start time
            selectedWordIndex = indexPath.item
            wordCollectionView.reloadData()
            
            let time = CMTime(seconds: segment.start, preferredTimescale: 600)
            updatePlayhead(to: time)
            delegate?.videoTimelineView(self, didScrubTo: time)
            return
        }
        
        // --- Thumbnail Collection View Tap Logic ---
        guard indexPath.item < thumbnailTimes.count else { return }
        
        let time = thumbnailTimes[indexPath.item]
        let playheadOffset = bounds.width / 2
        let cumulativeThumbnailWidthBefore = widthForItems(upTo: indexPath.item)
        let targetContentX = cumulativeThumbnailWidthBefore + volumeButtonWidth
        let newContentOffsetX = targetContentX - playheadOffset
        let finalContentOffsetX = max(newContentOffsetX, minContentOffsetX)
        
        collectionView.setContentOffset(CGPoint(x: finalContentOffsetX, y: 0), animated: true)
        
        let snappedSeconds = floor(time.seconds / majorMarkerInterval) * majorMarkerInterval
        let snappedTime = CMTime(seconds: snappedSeconds, preferredTimescale: time.timescale)
        
        self.updateTimeLabel(to: snappedTime)
        delegate?.videoTimelineView(self, didScrubTo: time)
    }
}

extension VideoTimelineView {
    
    // Call this from the ViewController AFTER the user saves the rename
    func updateWordSegmentText(at index: Int, newText: String) {
        guard index < wordSegments.count else { return }
        
        // 1. Update local data so the UI change is instantaneous
        wordSegments[index].text = newText
        
        // 2. Refresh just that cell
        let indexPath = IndexPath(item: index, section: 0)
        wordCollectionView.reloadItems(at: [indexPath])
    }
}

// MARK: - UICollectionViewDataSource
extension VideoTimelineView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == wordCollectionView {
            print("🔤 DEBUG: wordCollectionView reporting \(wordSegments.count) items.")
            return wordSegments.count
        }
        print("🔢 DEBUG: thumbnail collection reporting \(thumbnails.count) items.")
        return thumbnails.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if collectionView == wordCollectionView {
            let cell = wordCollectionView.dequeueReusableCell(withReuseIdentifier: WordCvCell.reuse, for: indexPath) as! WordCvCell
            
            let segment = wordSegments[indexPath.item]
            let isSelected = selectedWordIndex == indexPath.item
            
            cell.configure(text: segment.text, selected: isSelected)
            cell.onRenameCommit = { [weak self] newText in
                self?.handleWordRename(at: indexPath.item, newText: newText)
            }
            
            return cell
        }
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ThumbnailCell.reuseIdentifier, for: indexPath) as! ThumbnailCell
        
        guard indexPath.item < thumbnails.count else {
            print("❌ CRASH DEBUG: Index \(indexPath.item) requested but thumbnails.count is only \(thumbnails.count)")
            return cell // Return a safe, empty cell if out of bounds
        }
        
        cell.imageView.image = thumbnails[indexPath.item]
        
        var cornerMask: CACornerMask = []
        
        if indexPath.item == 0 {
            // First cell: Mask top-left and bottom-left
            cornerMask = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        } else if indexPath.item == thumbnails.count - 1 {
            // Last cell: Mask top-right and bottom-right
            cornerMask = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        } else {
            // Middle cells: No masking (empty set)
            cornerMask = []
        }
        
        cell.maskedCornerMask = cornerMask
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let volumeButtonView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: VolumeButtonView.reuseIdentifier, for: indexPath) as! VolumeButtonView
            volumeButtonView.updateMuteState(isMuted: isMuted)
            volumeButtonView.button.addTarget(self, action: #selector(didTapVolumeButton), for: .touchUpInside)
            return volumeButtonView
        }
        return UICollectionReusableView()
    }
    
}

// MARK: - UICollectionViewDelegateFlowLayout
extension VideoTimelineView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let totalSeconds = totalVideoDuration.seconds
        let segmentDuration = self.segmentDuration // 0.5
        let standardWidth = standardThumbnailWidth
        
        let isLastItem = indexPath.item == thumbnails.count - 1
        guard thumbnails.count > 0 else { return CGSize(width: standardWidth, height: thumbnailHeight) }
        
        if isLastItem {
            let timeCoveredByFullFrames = Double(thumbnails.count - 1) * segmentDuration
            let remainingTime = totalSeconds - timeCoveredByFullFrames
            
            if remainingTime > 0.01 {
                let dynamicWidth = CGFloat(remainingTime / segmentDuration) * standardWidth
                return CGSize(width: max(dynamicWidth, 10.0), height: thumbnailHeight)
            }
        }
        return CGSize(width: standardWidth, height: thumbnailHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: volumeButtonWidth, height: thumbnailHeight)
    }
}

// MARK: - ThumbnailCell (UICollectionViewCell)
class ThumbnailCell: UICollectionViewCell {
    
    static let reuseIdentifier = "ThumbnailCell"
    let imageView = UIImageView()
    
    var maskedCornerMask: CACornerMask = [] {
        didSet {
            // Apply mask whenever the property is set
            applyCornerMask()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupImageView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Re-apply the mask whenever the cell's bounds change
        applyCornerMask()
    }
    
    private func applyCornerMask() {
        // Apply the mask to the cell's layer and the image view's layer
        layer.maskedCorners = maskedCornerMask
        imageView.layer.maskedCorners = maskedCornerMask
    }
    
    private func setupImageView() {
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // ⭐ Apply the required layer settings to enable rounding
        layer.cornerRadius = 8
        layer.masksToBounds = true
        
        // Also apply to the image view to ensure the content is clipped
        imageView.layer.cornerRadius = 8
        imageView.layer.masksToBounds = true
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

// MARK: - VolumeButtonView (Supplementary View)
class VolumeButtonView: UICollectionReusableView {
    static let reuseIdentifier = "VolumeButtonView"
    let button = UIButton(type: .system)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupButton() {
        button.tintColor = .white
        button.backgroundColor = .clear
        button.layer.cornerRadius = 8
        button.clipsToBounds = true
        
        addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: centerXAnchor),
            button.centerYAnchor.constraint(equalTo: centerYAnchor),
            button.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.8),
            button.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.8)
        ])
    }
    
    func updateMuteState(isMuted: Bool) {
        button.setImage(isMuted ? .icMute : .icUnMute, for: .normal)
    }
}

// MARK: - TimeRulerView (Private Helper Class)
// This class was also defined at the end of your provided code and needs to be a top-level definition
// (or nested within VideoTimelineView, but top-level is cleaner for helpers).

private class TimeRulerView: UIView {
    
    func setupRuler(totalDurationSeconds: Double, thumbnailWidth: CGFloat, segmentDuration: Double, leadingOffset: CGFloat) {
        subviews.forEach { $0.removeFromSuperview() }
        
        let cellWidth = thumbnailWidth   // Width of one 0.25s cell
        let cellDuration = 0.25           // Fixed duration per cell
        
        // Loop through every 0.5 second interval (0.0, 0.25, 0.5, 0.75, 1.0...)
        for time in stride(from: 0.0, to: totalDurationSeconds + 0.01, by: cellDuration) {
            
            // 1. Calculate X Position
            // Since every cell is fixed 0.5s, we just count how many 0.5s steps we are in.
            let numberOfCells = CGFloat(time / segmentDuration)
            let xPosition = (numberOfCells * cellWidth) + leadingOffset
            
            // 2. Marker Drawing Logic
            
            // Draw Label on Whole Seconds (0.0, 1.0, 2.0...)
            if time.truncatingRemainder(dividingBy: 1.0) == 0 {
                
                let timeString: String
                if Int(time) % 60 == 0 && time >= 60 { // Only format 01:00 if >= 60s
                    let minutes = Int(time / 60)
                    timeString = String(format: "%02d:00", minutes)
                } else {
                    timeString = "\(Int(time))s"
                }
                
                let label = UILabel()
                label.text = timeString
                label.textColor = .colorABABAB
                label.font = UIFont.systemFont(ofSize: 14)
                
                label.sizeToFit()
                label.frame.origin.x = xPosition - (label.bounds.width / 2)
                label.frame.origin.y = 0
                
                addSubview(label)
                
            } else {
                // Draw Dot on Half Seconds (0.25, 0.5, 0.75...)
                if time < totalDurationSeconds {
                    // Optional: Make 0.5 dots slightly bigger/darker than 0.25 dots?
                    // For now, let's keep them uniform
                    let isHalfSecond = abs(time.truncatingRemainder(dividingBy: 0.5)) < 0.001
                    
                    let dotDiameter: CGFloat = isHalfSecond ? 6 : 4
                    let dotYPosition: CGFloat = isHalfSecond ? 5 : 6
                    let dotColor: UIColor = isHalfSecond ? .lightGray : .darkGray
                    
                    let dotView = UIView()
                    dotView.backgroundColor = dotColor
                    
                    dotView.frame.size = CGSize(width: dotDiameter, height: dotDiameter)
                    dotView.layer.cornerRadius = dotDiameter / 2.0
                    dotView.clipsToBounds = true
                    
                    dotView.frame.origin.x = xPosition - (dotDiameter / 2.0)
                    dotView.frame.origin.y = dotYPosition
                    
                    addSubview(dotView)
                }
            }
        }
    }

}

class PaddedLabel: UILabel {
    // Add padding to left and right
    var textInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + textInsets.left + textInsets.right,
                      height: size.height + textInsets.top + textInsets.bottom)
    }
}
