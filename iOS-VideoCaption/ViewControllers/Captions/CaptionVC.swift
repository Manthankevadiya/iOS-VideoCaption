//
//  CaptionVC.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 05/11/25.
//

import UIKit
import AVFoundation
import Hero
import CoreData
import Foundation

class CaptionVC: UIViewController {
    
    @IBOutlet weak var view_videoContainer: UIView!
    @IBOutlet weak var view_videoTimelineContainer: UIView!
    @IBOutlet weak var btn_undo: UIButton!
    @IBOutlet weak var btn_redo: UIButton!
    
    lazy var playPauseButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = 30
        button.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        button.addTarget(self, action: #selector(self.togglePlayback), for: .touchUpInside)
        return button
    }()
    
    lazy var view_animatedCaptionContainer: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = true
        view.clipsToBounds = true
        return view
    }()
    
    lazy var lbl_animatedCaption: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        label.textColor = .white
        label.numberOfLines = 0
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    var guideManager: LayoutGuideManager?
    
    var captionCenterXConstraint: NSLayoutConstraint?
    var captionCenterYConstraint: NSLayoutConstraint?
    var hasInitialCaptionPositionSet: Bool = false
    
    var videoTimelineView: VideoTimelineView!
    var hasInitialTimelinePositionSet: Bool = false
    var isUserScrubbingTimeline = Bool()
    
    var project : CaptionEntity!
    
    var captionTimeObserver: VideoTimeObserver?
    var captionFormatter : CaptionFormatter?
    let coreDataManager = CoreDataManager.shared
    
    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?
    var originalVideoAsset: AVAsset?
    
    var hideTimer: Timer?
    let autoHideDelay: TimeInterval = 2
    var captionWidthConstraint: NSLayoutConstraint?
    
    var selectionOverlay: CaptionSelectionOverlay?
    var isCaptionSelected: Bool = false {
        didSet {
            selectionOverlay?.isHidden = !isCaptionSelected
        }
    }
    private var captionSelectionHideTimer: Timer?
    private var wordRenamePanel: WordRenamePanelView?
    
    private let captionUndoManager = UndoManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setUpVideoPlayer()
        self.updateUndoRedoButtons()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.configureTimeLine()
        
        if let rect = self.calculatePureVideoRect() {
            self.playerLayer?.frame = rect
            
            self.playerLayer?.cornerRadius = 12
            self.playerLayer?.masksToBounds = true
            
            self.playerLayer?.videoGravity = .resizeAspectFill
            self.captionWidthConstraint?.constant = rect.width * 0.90
        } else {
            self.playerLayer?.frame = self.view_videoContainer.bounds
        }
        
        self.playPauseButton.center = CGPoint(x: self.view_videoContainer.bounds.midX,
                                                  y: self.view_videoContainer.bounds.midY)
        
        if !self.hasInitialCaptionPositionSet {
            self.applyCaptionPositionFromProject()
            self.hasInitialCaptionPositionSet = true
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.isHeroEnabled = true
        
        if !self.hasInitialCaptionPositionSet {
            self.view.layoutIfNeeded()
            
            self.applyCaptionPositionFromProject()
            self.hasInitialCaptionPositionSet = true
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.removePlaybackObservers()
        self.removeCaptionTimeObserver()
    }
    
    @IBAction func clickOnExport(_ sender: Any) {
        
        guard
            let videoLink = self.project.videoLink,
            let videoURL = FrameByFrameExporter.resolveVideoURL(from: videoLink),
            let formatter = self.captionFormatter
        else {
            print("❌ Missing videoURL or captionFormatter")
            return
        }
        
        // Make sure layout is up-to-date
        self.view_videoContainer.layoutIfNeeded()
        self.view_animatedCaptionContainer.layoutIfNeeded()
        self.lbl_animatedCaption.layoutIfNeeded()
        
        // 1. Video rect inside container (letterboxed area)
        let videoRect = self.calculateVideoRect(in: self.view_videoContainer)
        
        // 2. Get the actual caption container frame in the same coordinate system as videoRect
        // captionContainer is a subview of view_videoContainer already
        let captionFrameInContainer = self.view_animatedCaptionContainer.frame
        
        // 3. Intersect with video rect (so it never goes outside the video area)
        let stableRectInContainer: CGRect
        let intersection = captionFrameInContainer.intersection(videoRect)
        if !intersection.isNull {
            stableRectInContainer = intersection
        } else {
            // Fallback if for some reason there's no intersection
            stableRectInContainer = captionFrameInContainer
        }
        
        // 4. Convert to a frame relative to the videoRect origin (so 0,0 is top-left of video content)
        let uiCaptionFrameInVideoSpace = CGRect(
            x: stableRectInContainer.origin.x - videoRect.origin.x,
            y: stableRectInContainer.origin.y - videoRect.origin.y,
            width: stableRectInContainer.width,
            height: stableRectInContainer.height
        )
        
        // 5. Build export configuration
        let fontName = self.project.captionFontName ?? "PingFangTC-Semibold"
        let fontSize = CGFloat(self.project.captionFontSize)
        
        let textColor = UIColor(hex: self.project.captionFontColor ?? "FFFFFF")
        let highlightColor = UIColor(hex: self.project.captionHighlightColor ?? "FFFFFF")
        let borderColor = UIColor(hex: self.project.borderColor ?? "000000")
        let borderWidth = CGFloat(self.project.borderThickness)
        let shadowColor = UIColor(hex: self.project.shadowColor ?? "000000")
        let shadowradius = CGFloat(self.project.shadowRadius)
        
        let config = ExportConfiguration(
            videoURL: videoURL,
            style: self.resolveCurrentCaptionStyle(),
            captionFormatter: formatter,
            
            fontName: fontName,
            fontSize: fontSize,
            textColor: textColor,
            highlightColor: highlightColor,
            borderColor: borderColor,
            borderWidth: borderWidth,
            shadowColor: shadowColor,
            shadowRadius: shadowradius,
            shadowOpacity: 1,
            defaultWordDuration: 0.3,
            
            // Use the videoRect.size as the reference canvas,
            // so export scaling matches the visible video content.
            referenceCanvasSize: videoRect.size,
            uiCaptionFrame: uiCaptionFrameInVideoSpace
        )
        
        print("🎥 Video Rect: \(videoRect)")
        print("🏷️ Caption UI Frame (in video space): \(uiCaptionFrameInVideoSpace)")
        
        FrameByFrameExporter.export(config: config) { success, url, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Saved to Gallery at: \(url?.path ?? "")")
                } else {
                    print("❌ Export error: \(error?.localizedDescription ?? "Unknown")")
                }
            }
        }
    }
    
    @IBAction func clickOnBack(_ sender: Any) {
        self.navigationController?.popToRootViewController(animated: true)
    }
    
    @IBAction func clickOnUndo(_ sender: UIButton) {
        guard captionUndoManager.canUndo else { return }
            captionUndoManager.undo()
            updateUndoRedoButtons()
    }
    
    @IBAction func clickOnRedo(_ sender: UIButton) {
        guard captionUndoManager.canRedo else { return }
            captionUndoManager.redo()
            updateUndoRedoButtons()
    }
    
    @IBAction func clickOnStyle(_ sender: Any) {
        let vc = EditCaptionStyleVC.instantiate()
        vc.modalPresentationStyle = .overCurrentContext
        vc.transitioningDelegate = Hero.shared
        vc.project = self.project
        vc.clickedOnDone = { [weak self] in
            guard let self = self else { return }
            
            self.loadCaptionDataAndFormat()
            self.startCaptionSynchronization()
            
            if let currentTime = self.player?.currentTime().seconds {
                self.handleTimeUpdate(currentTime: currentTime)
            }
            
            self.view.layoutIfNeeded()
        }
        self.present(vc, animated: true)
    }
    
    @IBAction func clickOnEdit(_ sender: Any) {
        self.presentResetConfirmation()
    }
    
}

// MARK: Player SetUp
extension CaptionVC {
    
    func setUpVideoPlayer() {
        guard let absoluteURL = self.project.currentAbsoluteVideoURL else {
            print("❌ Error: Could not get absolute URL for video.")
            self.popVC()
            return
        }
        
        self.loadCaptionDataAndFormat()
        
        let player = AVPlayer(url: absoluteURL)
        self.player = player
        
        self.addPlaybackObservers()
        
        self.originalVideoAsset = AVAsset(url: absoluteURL)
        self.setUpCaptionContainer()
        self.setUpVideoTimelineView()
        
        self.startCaptionSynchronization()
        
        self.view_videoContainer.layoutIfNeeded()
        self.guideManager = LayoutGuideManager(container: self.view_videoContainer)
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.frame = self.view_videoContainer.bounds
        self.playerLayer = playerLayer
        
        self.playerLayer?.cornerRadius = 12
        self.playerLayer?.masksToBounds = true
        
        self.view_videoContainer.layer.addSublayer(playerLayer)
        self.view_videoContainer.addSubview(self.playPauseButton)
        
        self.view_videoContainer.bringSubviewToFront(self.view_animatedCaptionContainer)
        self.view_videoContainer.bringSubviewToFront(self.playPauseButton)
        
        player.pause()
        self.playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTapGesture(_:)))
        self.view_videoContainer.addGestureRecognizer(tapGesture)
    }
    
    @objc func handleTapGesture(_ gesture: UITapGestureRecognizer) {
        self.showControls()
    }
    
    func addPlaybackObservers() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.playerDidFinishPlaying),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: self.player?.currentItem)
    }
    
    func removePlaybackObservers() {
        NotificationCenter.default.removeObserver(self,
                                                  name: .AVPlayerItemDidPlayToEndTime,
                                                  object: self.player?.currentItem)
    }
    
    @objc func playerDidFinishPlaying(note: Notification) {
        guard let player = self.player else { return }
        
        // 1. Seek video to 0 synchronously
        let zero = CMTime(seconds: 0, preferredTimescale: 600)
        player.seek(to: zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let self = self else { return }
            
            // 2. Reset timeline UI
            self.isUserScrubbingTimeline = false
            self.videoTimelineView.updatePlayhead(to: zero)
            self.videoTimelineView.updateTimeLabel(to: zero)
            
            // 3. Reset caption label to base state
            self.lbl_animatedCaption.normalTextedLabel()
            
            // 4. Force one manual time update so animator state matches 0
            self.handleTimeUpdate(currentTime: 0)
            
            // 5. UI: show play button, pause player
            player.pause()
            self.playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            self.showControls()
        }
    }
    
    // Helper that calculates rect WITHOUT relying on playerLayer properties
    func calculatePureVideoRect() -> CGRect? {
        guard let asset = self.originalVideoAsset,
              let track = asset.tracks(withMediaType: .video).first else { return nil }
        
        let videoSize = track.naturalSize.applying(track.preferredTransform)
        let w = abs(videoSize.width)
        let h = abs(videoSize.height)
        
        if w == 0 || h == 0 { return nil }
        
        let containerRect = self.view_videoContainer.bounds
        let ratio = min(containerRect.width / w, containerRect.height / h)
        
        let newW = w * ratio
        let newH = h * ratio
        
        let x = (containerRect.width - newW) / 2
        let y = (containerRect.height - newH) / 2
        
        return CGRect(x: x, y: y, width: newW, height: newH)
    }
    
    @objc func togglePlayback() {
        guard let player = self.player else { return }
        
        self.showControls()
        
        if player.rate != 0 && player.error == nil {
            player.pause()
            self.playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        } else {
            player.play()
            self.playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        }
    }
    
    func showControls() {
        self.hideTimer?.invalidate()
        UIView.animate(withDuration: 0.3) {
            self.playPauseButton.alpha = 1.0
        }
        self.startHideTimer()
    }
    
    func hideControls() {
        UIView.animate(withDuration: 0.5) {
            self.playPauseButton.alpha = 0.0
        }
    }
    
    func startHideTimer() {
        self.hideTimer?.invalidate()
        self.hideTimer = Timer.scheduledTimer(withTimeInterval: autoHideDelay, repeats: false) { [weak self] _ in
            self?.hideControls()
        }
    }
    
    // For Undo or redo
    private func refreshUIAfterUndoRedo() {
        self.loadCaptionDataAndFormat()

        if let currentTime = self.player?.currentTime().seconds {
            self.handleTimeUpdate(currentTime: currentTime)
        }

        self.loadAndConfigureWordSegments()
    }

    func restoreCaptionPosition(x: CGFloat, y: CGFloat) {

        // 1. Capture CURRENT state (this becomes REDO)
        let currentX = CGFloat(self.project.captionPositionX)
        let currentY = CGFloat(self.project.captionPositionY)

        // 2. REGISTER REDO
        captionUndoManager.registerUndo(withTarget: self) { target in
            target.restoreCaptionPosition(x: currentX, y: currentY)
        }

        captionUndoManager.setActionName("Move Caption")

        // 3. APPLY UNDO STATE
        self.project.captionPositionX = Float(x)
        self.project.captionPositionY = Float(y)
        self.coreDataManager.saveContext()

        // 4. UPDATE UI
        self.applyCaptionPositionFromProject()

        if let currentTime = self.player?.currentTime().seconds {
            self.handleTimeUpdate(currentTime: currentTime)
        }

        self.updateUndoRedoButtons()
    }
    
    private func updateUndoRedoButtons() {
        btn_undo.isEnabled = captionUndoManager.canUndo
        btn_redo.isEnabled = captionUndoManager.canRedo

        btn_undo.alpha = captionUndoManager.canUndo ? 1.0 : 0.4
        btn_redo.alpha = captionUndoManager.canRedo ? 1.0 : 0.4
    }
    
    // For reset Video
    private func presentResetConfirmation() {
        let alert = UIAlertController(
            title: "Reset Video",
            message: "This will reset the video to its original state. All edits will be lost and cannot be undone.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { _ in
            self.resetVideoToInitialState()
        })

        present(alert, animated: true)
    }
    
    private func resetVideoToInitialState() {

        // 1. Stop playback
        player?.pause()
        player = nil

        // 2. Remove player layer
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil

        // 3. Remove observers & timers
        removePlaybackObservers()
        captionSelectionHideTimer?.invalidate()
        captionSelectionHideTimer = nil

        // 4. Clear caption UI
        view_animatedCaptionContainer.subviews.forEach { $0.removeFromSuperview() }

        // 5. Reset Core Data project state
        resetProjectToInitialState()

        // 6. CLEAR UNDO / REDO COMPLETELY
        captionUndoManager.removeAllActions()
        updateUndoRedoButtons()

        // 7. Reset helpers
        guideManager = nil
        isCaptionSelected = false

        // 8. Rebuild EVERYTHING like first launch
        setUpVideoPlayer()
    }
    
    private func resetProjectToInitialState() {

        // Reset caption position
        project.captionPositionX = 0
        project.captionPositionY = 0

        // Reset caption text to original transcription
        let context = coreDataManager.persistentContainer.viewContext
        let request: NSFetchRequest<TranscribedEntity> = TranscribedEntity.fetchRequest()

        if let entities = try? context.fetch(request) {
            for entity in entities {
                entity.text = entity.text
            }
        }

        coreDataManager.saveContext()
    }

}

// MARK: Caption Data
extension CaptionVC {
    
    func loadCaptionDataAndFormat() {
        // 1. Fetch TranscribedEntity objects from Core Data
        let transcribedEntities = self.coreDataManager.fetchTranscription(for: self.project)
        
        guard !transcribedEntities.isEmpty else {
            print("Warning: No transcribed words found in Core Data for this project.")
            // ⭐️ Ensure the caption formatter is nil or empty to prevent crashes
            self.captionFormatter = CaptionFormatter(wordsPerLine: 0, maxCaptionWidth: 0, font: .systemFont(ofSize: 1))
            return
        }
        
        // 2. Convert TranscribedEntity objects to TimedWord structs
        let timedWords: [TimedWord] = transcribedEntities.map { entity in
            let duration = entity.endTime - entity.startTime
            return TimedWord(
                word: entity.text ?? "",
                startTime: entity.startTime,
                duration: duration
            )
        }
        
        // --- New Layout Calculation for Dynamic Breaks ---
        
        // 1. Calculate the active video frame relative to the player view.
        let videoRect = self.calculateVideoRect(in: self.view_videoContainer)
        let buffer: CGFloat = 4.0
        
        // 2. Define the max width for the text. Use 95% of the videoRect width
        // to give some safe margins, matching the Auto Layout constraint.
        let maxTextWidth = (videoRect.width * 0.95) - buffer
        
        // 3. Get the font used for the caption (must match what's used in updateCaptionLabel)
        let captionFontSize = CGFloat(self.project.captionFontSize)
        let captionFont = UIFont(name: self.project.captionFontName ?? "", size: captionFontSize) ?? .systemFont(ofSize: 20, weight: .medium)
        
        // 4. Initialize/Re-initialize the formatter with the new layout info
        let wordsPerLine = Int(self.project.wordsPerLine)
        
        self.captionFormatter = CaptionFormatter(
            wordsPerLine: wordsPerLine,
            maxCaptionWidth: maxTextWidth,
            font: captionFont
        )
        
        // 5. Format the words into structured lines
        self.captionFormatter?.formatCaptions(from: timedWords)
        
        print("✅ Core Data Sync: Loaded \(timedWords.count) words and formatted into \(self.captionFormatter?.captionLines.count ?? 0) caption lines.")
    }
    
}

// MARK: TimeLineView SetUp
extension CaptionVC {
    func configureTimeLine() {
        if !self.hasInitialTimelinePositionSet {
            if self.videoTimelineView?.bounds.width ?? 0 > 0 {
                if let asset = self.originalVideoAsset {
                    self.videoTimelineView.configure(with: asset)
                    self.loadAndConfigureWordSegments()
                    self.hasInitialTimelinePositionSet = true
                }
            }
        }
    }
    
    func setUpVideoTimelineView() {
        self.videoTimelineView = VideoTimelineView()
        self.videoTimelineView.project = self.project
        self.videoTimelineView.delegate = self
        
        self.view_videoTimelineContainer.addSubview(self.videoTimelineView)
        
        self.videoTimelineView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.videoTimelineView.topAnchor.constraint(equalTo: self.view_videoTimelineContainer.topAnchor),
            self.videoTimelineView.leadingAnchor.constraint(equalTo: self.view_videoTimelineContainer.leadingAnchor),
            self.videoTimelineView.trailingAnchor.constraint(equalTo: self.view_videoTimelineContainer.trailingAnchor),
            self.videoTimelineView.bottomAnchor.constraint(equalTo: self.view_videoTimelineContainer.bottomAnchor)
        ])
        
        if let asset = self.originalVideoAsset {
            self.videoTimelineView.configure(with: asset)
            self.loadAndConfigureWordSegments()
        }
    }
    
    func loadAndConfigureWordSegments() {
        // 1. Fetch from Core Data (Sorted by startTime)
        let entities = self.coreDataManager.fetchTranscription(for: self.project)
        
        // 2. Map to WordSegment
        let segments = entities.map { entity in
            WordSegment(
                objectID: entity.objectID,
                text: entity.text ?? "",
                start: entity.startTime,
                duration: entity.endTime - entity.startTime
            )
        }
        
        // 3. Pass to Timeline
        self.videoTimelineView.setWordSegments(segments)
    }
}

extension CaptionVC: VideoTimelineViewDelegate {
    
    func videoTimelineDidRequestRenameWord(at index: Int, currentText: String, objectID: NSManagedObjectID?) {
        presentRenameWordPopup(
            index: index,
            currentText: currentText,
            objectID: objectID
        )
    }
    
    func videoTimelineView(_ timelineView: VideoTimelineView, didScrubTo time: CMTime) {
        if self.player?.rate != 0 && self.player?.error == nil {
            self.player?.pause()
            self.playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        }
        
        self.isUserScrubbingTimeline = true
        self.player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    func videoTimelineViewDidEndScrubbing(_ timelineView: VideoTimelineView) {
        self.isUserScrubbingTimeline = false
    }
    
    func timelineDidToggleMute(isMuted: Bool) {
        if let player = self.player {
            player.isMuted = isMuted
            print("Video player mute state set to: \(isMuted)")
        }
    }
    
    func videoTimelineDidRenameWord(at index: Int,newText: String,objectID: NSManagedObjectID?) {
        guard let objectID = objectID else { return }

        let context = coreDataManager.persistentContainer.viewContext

        context.perform {
            do {
                guard let entity = try context.existingObject(with: objectID) as? TranscribedEntity else {
                    return
                }

                let oldText = entity.text ?? ""
                guard oldText != newText else { return }

                // ✅ REGISTER REDO
                self.captionUndoManager.registerUndo(withTarget: self) { target in
                    target.videoTimelineDidRenameWord(
                        at: index,
                        newText: oldText,
                        objectID: objectID
                    )
                }

                self.captionUndoManager.setActionName("Rename Word")

                // Apply change
                entity.text = newText
                self.coreDataManager.saveContext()

                DispatchQueue.main.async {
                    self.refreshUIAfterUndoRedo()
                    self.updateUndoRedoButtons()
                }

            } catch {
                print("❌ Rename error: \(error)")
            }
        }
    }
    
    private func presentRenameWordPopup(index: Int, currentText: String, objectID: NSManagedObjectID?) {
        // Pause video if playing
        if self.player?.rate != 0 {
            self.player?.pause()
            self.playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        }
        
        // Create panel if needed
        if wordRenamePanel == nil {
            wordRenamePanel = WordRenamePanelView()
            wordRenamePanel?.delegate = self
        }
        
        // Get all word segments from timeline
        let segments = self.coreDataManager.fetchTranscription(for: self.project).map { entity in
            WordSegment(
                objectID: entity.objectID,
                text: entity.text ?? "",
                start: entity.startTime,
                duration: entity.endTime - entity.startTime
            )
        }
        
        // Show panel
        wordRenamePanel?.show(
            in: self.view,
            segments: segments,
            selectedIndex: index,
            objectID: objectID
        )
    }
    
}

// Add this extension at the bottom of CaptionVC.swift
extension CaptionVC: WordRenamePanelDelegate {
    func wordRenamePanelDidSave(_ panel: WordRenamePanelView, newText: String, index: Int, objectID: NSManagedObjectID?) {
        // Perform the rename
        self.videoTimelineDidRenameWord(at: index, newText: newText, objectID: objectID)
    }
    
    func wordRenamePanelDidCancel(_ panel: WordRenamePanelView) {
        // Optional: Resume playback or any other action
        print("User cancelled word rename")
    }
}

// MARK: Caption Label SetUp
extension CaptionVC {
    
    func setUpCaptionContainer() {
        guard let playerView = self.view_videoContainer else { return }
        
        // 1. Prepare views
        self.view_animatedCaptionContainer.translatesAutoresizingMaskIntoConstraints = false
        self.lbl_animatedCaption.translatesAutoresizingMaskIntoConstraints = false
        
        playerView.addSubview(self.view_animatedCaptionContainer)
        self.view_animatedCaptionContainer.addSubview(self.lbl_animatedCaption)
        
        // 2. NEW: Add the Selection Overlay
        let overlay = CaptionSelectionOverlay()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.isHidden = true // Hidden by default
        self.selectionOverlay = overlay
        self.view_animatedCaptionContainer.addSubview(overlay)
        
        // 3. Pin Overlay to container edges
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view_animatedCaptionContainer.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view_animatedCaptionContainer.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: view_animatedCaptionContainer.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view_animatedCaptionContainer.trailingAnchor)
        ])
        
        // 4. Setup Label Constraints (with slightly more padding for handles)
        let verticalPadding: CGFloat = 12
        let horizontalPadding: CGFloat = 10
        
        NSLayoutConstraint.activate([
            self.lbl_animatedCaption.centerXAnchor.constraint(equalTo: self.view_animatedCaptionContainer.centerXAnchor),
            self.lbl_animatedCaption.widthAnchor.constraint(lessThanOrEqualTo: self.view_animatedCaptionContainer.widthAnchor, constant: -(horizontalPadding * 2)),
            self.lbl_animatedCaption.topAnchor.constraint(equalTo: self.view_animatedCaptionContainer.topAnchor, constant: verticalPadding / 2),
            self.lbl_animatedCaption.bottomAnchor.constraint(equalTo: self.view_animatedCaptionContainer.bottomAnchor, constant: -verticalPadding / 2)
        ])
        
        // 5. Setup Container Position Constraints
        let centerXConstraint = self.view_animatedCaptionContainer.centerXAnchor.constraint(equalTo: playerView.centerXAnchor, constant: 0)
        let centerYConstraint = self.view_animatedCaptionContainer.centerYAnchor.constraint(equalTo: playerView.topAnchor, constant: playerView.bounds.midY)
        
        self.captionCenterXConstraint = centerXConstraint
        self.captionCenterYConstraint = centerYConstraint
        
        let widthConstraint = self.view_animatedCaptionContainer.widthAnchor.constraint(lessThanOrEqualToConstant: playerView.bounds.width * 0.95)
        self.captionWidthConstraint = widthConstraint
        
        NSLayoutConstraint.activate([
            widthConstraint,
            centerXConstraint,
            centerYConstraint
        ])
        
        self.view_animatedCaptionContainer.heroID = "captionLabel"
        self.updateCaptionLabelStyle()
        
        // 6. GESTURES: Pan for moving AND Tap for selecting
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.handlePanGesture(_:)))
        self.view_animatedCaptionContainer.addGestureRecognizer(panGesture)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleCaptionTap))
        self.view_animatedCaptionContainer.addGestureRecognizer(tapGesture)
        
        // Tap on video background to deselect
        let backgroundTap = UITapGestureRecognizer(target: self, action: #selector(self.handleBackgroundTap))
        playerView.addGestureRecognizer(backgroundTap)
    }
    
    @objc func handleCaptionTap() {
        self.isCaptionSelected = true
        // If the user just taps, we start the timer to hide it after 2 seconds
        self.startCaptionHideTimer()
    }
    
    @objc func handleBackgroundTap() {
        self.captionSelectionHideTimer?.invalidate()
        self.isCaptionSelected = false
    }
    
    func updateCaptionLabelStyle() {
        // --- A. Resolve Font ---
        let captionFontSize = CGFloat(self.project.captionFontSize)
        let captionFont = UIFont(
            name: self.project.captionFontName ?? UIFont.systemFont(ofSize: 20, weight: .medium).fontName,
            size: captionFontSize
        ) ?? .systemFont(ofSize: 20, weight: .medium)
        
        // --- B. Resolve Text Color ---
        let textColor: UIColor = {
            if let hex = self.project.captionFontColor {
               let color = UIColor(hex: hex)
                // Assuming you have a standard UIColor(hex:) initializer available
                return color
            }
            return .white // Default
        }()
        
        // --- C. Apply to Label ---
        self.lbl_animatedCaption.font = captionFont
        self.lbl_animatedCaption.textColor = textColor
        self.lbl_animatedCaption.numberOfLines = 1
    }
    
    func applyCaptionPositionFromProject() {
        guard let playerView = self.view_videoContainer,
              let centerXConstraint = self.captionCenterXConstraint,
              let centerYConstraint = self.captionCenterYConstraint else { return }
        
        self.view_animatedCaptionContainer.layoutIfNeeded()
        
        // Calculate the active video frame (takes into account aspect ratio)
        let videoRect = self.calculateVideoRect(in: playerView)
        print("Video Rect: \(videoRect)")
        
        // 1. Get Normalized Position (Core Data values)
        var normalizedX = CGFloat(self.project.captionPositionX)
        
        if abs(normalizedX - 0.5) < 0.01 {
            normalizedX = 0.5
        }
        
        let normalizedY = CGFloat(self.project.captionPositionY)
        
        // 2. Get the container size. This should be accurate if layoutIfNeeded() ran.
        let containerHalfWidth = self.view_animatedCaptionContainer.bounds.width / 2.0
        let containerHalfHeight = self.view_animatedCaptionContainer.bounds.height / 2.0
        
        // 3. Calculate absolute center point (relative to playerView's top-left (0,0))
        var newAbsoluteCenterX = videoRect.minX + (videoRect.width * normalizedX)
        var newAbsoluteCenterY = videoRect.minY + (videoRect.height * normalizedY)
        
        // 4. Clamping (Prevents caption from leaving the video boundary)
        
        // Clamping ensures the calculated center point is at least (half size) away from the video edge.
        let minAllowedCenterX = videoRect.minX + containerHalfWidth
        let maxAllowedCenterX = videoRect.maxX - containerHalfWidth
        let minAllowedCenterY = videoRect.minY + containerHalfHeight
        let maxAllowedCenterY = videoRect.maxY - containerHalfHeight
        
        if minAllowedCenterX < maxAllowedCenterX {
            newAbsoluteCenterX = max(minAllowedCenterX, newAbsoluteCenterX)
            newAbsoluteCenterX = min(maxAllowedCenterX, newAbsoluteCenterX)
        } else {
            newAbsoluteCenterX = videoRect.midX
        }
        
        newAbsoluteCenterY = max(minAllowedCenterY, newAbsoluteCenterY)
        newAbsoluteCenterY = min(maxAllowedCenterY, newAbsoluteCenterY)
        
        let playerViewCenterX = playerView.bounds.midX
        let newXOffsetFromPlayerCenter = newAbsoluteCenterX - playerViewCenterX
        
        // 5. Apply new absolute positions to constraints
        centerXConstraint.constant = newXOffsetFromPlayerCenter
        centerYConstraint.constant = newAbsoluteCenterY
        
        // Apply changes immediately
        playerView.layoutIfNeeded()
        
        print("Caption Position Updated: (\(String(format: "%.1f", newAbsoluteCenterX)), \(String(format: "%.1f", newAbsoluteCenterY)))")
    }
    
    func calculateVideoRect(in playerView: UIView) -> CGRect {
        if let layer = self.playerLayer {
            return layer.frame
        } else {
            return playerView.bounds
        }
    }
    
    @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {

        guard let captionView = gesture.view,
              let boundsView = self.view_videoContainer,
              let centerXConstraint = self.captionCenterXConstraint,
              let centerYConstraint = self.captionCenterYConstraint,
              let guides = self.guideManager else { return }

        captionView.layoutIfNeeded()

        let translation = gesture.translation(in: boundsView)
        let videoRect = self.calculateVideoRect(in: boundsView)

        // Player view center reference
        let playerViewCenterX = boundsView.bounds.midX

        // Current absolute center values
        let startCenterX = playerViewCenterX + centerXConstraint.constant
        let startCenterY = centerYConstraint.constant

        // Proposed new center
        var proposedX = startCenterX + translation.x
        var proposedY = startCenterY + translation.y

        // ---- CLAMPING TO VIDEO RECT ----
        let halfWidth = captionView.bounds.width / 2
        let halfHeight = captionView.bounds.height / 2

        let minX = videoRect.minX + halfWidth
        let maxX = videoRect.maxX - halfWidth
        let minY = videoRect.minY + halfHeight
        let maxY = videoRect.maxY - halfHeight

        if minX < maxX {
            proposedX = max(minX, min(maxX, proposedX))
        } else {
            proposedX = videoRect.midX
        }

        proposedY = max(minY, min(maxY, proposedY))

        switch gesture.state {

        case .began:
            captionUndoManager.beginUndoGrouping()
            self.isCaptionSelected = true
            self.captionSelectionHideTimer?.invalidate()
            guides.beginDrag(videoRect: videoRect)

        case .changed:
            let snappedCenter = guides.updateDrag(
                currentCenter: CGPoint(x: proposedX, y: proposedY),
                videoRect: videoRect,
                captionSize: captionView.bounds.size
            )

            // Convert absolute center back to constraints
            centerXConstraint.constant = snappedCenter.x - playerViewCenterX
            centerYConstraint.constant = snappedCenter.y

            gesture.setTranslation(.zero, in: boundsView)

        case .ended, .cancelled:
            guides.endDrag()

            let finalCenterX = playerViewCenterX + centerXConstraint.constant
            let finalCenterY = centerYConstraint.constant

            let oldX = CGFloat(self.project.captionPositionX)
            let oldY = CGFloat(self.project.captionPositionY)

            captionUndoManager.registerUndo(withTarget: self) { target in
                target.restoreCaptionPosition(x: oldX, y: oldY)
            }

            captionUndoManager.endUndoGrouping()

            self.saveCurrentCaptionPosition(
                centerX: finalCenterX,
                centerY: finalCenterY,
                in: boundsView
            )
            updateUndoRedoButtons()
            
        default:
            break
        }
    }
    
    func saveCurrentCaptionPosition(centerX: CGFloat, centerY: CGFloat, in playerView: UIView) {
        let videoRect = self.calculateVideoRect(in: playerView)
        
        // 1. Calculate the position relative to the video frame origin
        let positionXInVideo = centerX - videoRect.minX
        let positionYInVideo = centerY - videoRect.minY
        
        // 2. Normalize the position (0.0 to 1.0)
        let normalizedX = positionXInVideo / videoRect.width
        let normalizedY = positionYInVideo / videoRect.height
        
        // 3. Update the Core Data properties
        self.project.captionPositionX = Float(normalizedX)
        self.project.captionPositionY = Float(normalizedY)
        
        // 4. Persist the changes
        self.coreDataManager.saveContext()
        
        print("Caption Position Saved: X=\(String(format: "%.3f", normalizedX)), Y=\(String(format: "%.3f", normalizedY))")
    }
    
    private func startCaptionHideTimer() {
            // Invalidate any existing timer first
            self.captionSelectionHideTimer?.invalidate()
            
            // Start a new timer for 1 or 2 seconds (VN/Canva usually wait 1.5 - 2s)
            self.captionSelectionHideTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                UIView.animate(withDuration: 0.3) {
                    self?.isCaptionSelected = false
                }
            }
        }
    
}

extension CaptionVC {

    func startCaptionSynchronization() {
        guard let player = self.player else { return }

        // 1. Clean up any old observers before starting a new one
        self.removeCaptionTimeObserver()
        
        // 2. Initialize the VideoTimeObserver, delegating time updates to the handler
        self.captionTimeObserver = VideoTimeObserver(player: player) { [weak self] time in
            self?.handleTimeUpdate(currentTime: time)
        }
    }
    
    func removeCaptionTimeObserver() {
        self.captionTimeObserver = nil // Triggers deinit in VideoTimeObserver
    }

    /// The single point of entry for all time updates from the AVPlayer.
    func handleTimeUpdate(currentTime: Double) {
        
        // 1. Timeline Update (Always runs unless scrubbing)
        if !self.isUserScrubbingTimeline {
            let cmTime = CMTime(seconds: currentTime, preferredTimescale: 600)
            self.videoTimelineView.updatePlayhead(to: cmTime)
        }
        
        // 2. Animated Caption Drive
        guard let formatter = self.captionFormatter else {
            self.lbl_animatedCaption.normalTextedLabel()
            return
        }
        
        // Find the currently active line
        guard let activeLine = formatter.captionLine(for: currentTime) else {
            self.lbl_animatedCaption.normalTextedLabel()
            return
        }
        
        let captionStyle: TextAnimationStyle = self.resolveCurrentCaptionStyle()
        let highlightColor: UIColor? = self.resolveCurrentHighlightColor()
        let fontColor: UIColor? = resolveCurrentTextColor()
        let fontName: String = resolveCurrentFontName()
        let fontSize: CGFloat = resolveCurrentFontSize()
        let borderColor: UIColor? = resolveCurrentBorderColor()
        let borderWidth: CGFloat = resolveCurrentBorderWidth()
        let shadowColor: UIColor? = resolveCurrentShadowColor()
        let shadowRadius: CGFloat = resolveCurrentShadowRadius()
        
        let wordCount = Double(activeLine.words.count)
        let lineDuration = activeLine.endTime - activeLine.startTime
        
        // 1. GENERATE PRECISE TIMINGS (Start Times)
        let relativeTimings: [Double] = activeLine.words.map { word in
            return word.startTime - activeLine.startTime
        }
        
        // 2. GENERATE PRECISE DURATIONS (End - Start)
        let specificDurations: [Double] = activeLine.words.map { word in
            return word.duration // Assuming TimedWord has a .duration property
        }
        
        // Call the specialized UILabel extension method to handle speed adjustment and animation
        self.lbl_animatedCaption.updateAnimationFromLine(
            rawTime: currentTime,
            lineStartTime: activeLine.startTime,
            text: activeLine.text,
            fontName: fontName,
            wordCount: wordCount,
            lineDuration: lineDuration,
            style: captionStyle,
            highlightColor: highlightColor,
            fontColor: fontColor,
            timings: relativeTimings,
            durations: specificDurations,
            fontSize: fontSize,
            borderWidth: borderWidth,
            borderColor: borderColor ?? .clear,
            shadowColor: shadowColor ?? .clear,
            shadowRadius: shadowRadius
        )
    }
    
    // --- Helper Functions to resolve dynamic project settings ---
    private func resolveCurrentCaptionStyle() -> TextAnimationStyle {
        let styleName = self.project.captionAnimationType ?? TextAnimationStyle.popWord.rawValue
        return TextAnimationStyle(rawValue: styleName) ?? .popWord
    }
    
    private func resolveCurrentHighlightColor() -> UIColor? {
        guard let hex = self.project.captionHighlightColor else { return nil }
        return UIColor(hex: hex)
    }
    
    private func resolveCurrentTextColor() -> UIColor? {
        guard let hex = self.project.captionFontColor else { return nil }
        return UIColor(hex: hex)
    }
    
    private func resolveCurrentFontName() -> String {
        guard let fontName = self.project.captionFontName else { return "PingFangTC-Semibold" }
        return fontName
    }
    
    private func resolveCurrentFontSize() -> CGFloat {
        let fontName = self.project.captionFontSize
        return CGFloat(fontName)
    }
    
    private func resolveCurrentBorderColor() -> UIColor? {
        guard let hex = self.project.borderColor else { return nil }
        return UIColor(hex: hex)
    }
    
    private func resolveCurrentBorderWidth() -> CGFloat {
        let thickness = self.project.borderThickness
        return CGFloat(thickness)
    }
    
    private func resolveCurrentShadowColor() -> UIColor? {
        guard let hex = self.project.shadowColor else { return nil }
        return UIColor(hex: hex)
    }
    
    private func resolveCurrentShadowRadius() -> CGFloat {
        let thickness = self.project.shadowRadius
        return CGFloat(thickness)
    }
    
}

class CaptionSelectionOverlay: UIView {
    private let borderLayer = CAShapeLayer()
    private let handleSize: CGFloat = 12.0
    private let sideHandleWidth: CGFloat = 10
    private let sideHandleHeight: CGFloat = 20.0
    
    var themeColor: UIColor = .white

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupOverlay()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupOverlay()
    }

    private func setupOverlay() {
        // IMPORTANT: This allows your PanGesture on the container to work!
        self.isUserInteractionEnabled = false
        
        borderLayer.strokeColor = themeColor.cgColor
        borderLayer.fillColor = nil
        borderLayer.lineWidth = 2.5
        borderLayer.lineDashPattern = [4, 3]
        layer.addSublayer(borderLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        borderLayer.path = UIBezierPath(rect: bounds).cgPath
        borderLayer.frame = bounds
        updateHandles()
    }

    private func updateHandles() {
        subviews.forEach { $0.removeFromSuperview() }
        
        // 1. Corner Dots
        let corners = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: bounds.width, y: 0),
            CGPoint(x: 0, y: bounds.height),
            CGPoint(x: bounds.width, y: bounds.height)
        ]
        corners.forEach { createHandle(at: $0, size: CGSize(width: handleSize, height: handleSize), isCircle: true) }
        
        // 2. Side Handles
        let sides = [
            CGPoint(x: 0, y: bounds.height / 2),
            CGPoint(x: bounds.width, y: bounds.height / 2)
        ]
        sides.forEach { createHandle(at: $0, size: CGSize(width: sideHandleWidth, height: sideHandleHeight), isCircle: false) }
    }

    private func createHandle(at point: CGPoint, size: CGSize, isCircle: Bool) {
        let handle = UIView(frame: CGRect(origin: .zero, size: size))
        handle.backgroundColor = .white
        handle.layer.borderColor = themeColor.cgColor
        handle.layer.borderWidth = 1.5
        handle.center = point
        handle.layer.cornerRadius = isCircle ? size.width / 2 : 2
        addSubview(handle)
    }
}
