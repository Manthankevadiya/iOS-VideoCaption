//
//  SwiftUITextAnimator.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 02/12/25.
//

import AVFoundation
import Photos
import SwiftUI
import UIKit
import CoreImage
import Combine
import ObjectiveC
import CoreMedia

final class UILabelAnimator {
    
    // MARK: - Configuration Properties
    /// The text to be animated. Must be set before starting the animation.
    var text: String = "Example Animated Text"
    
    var fontSize: CGFloat = 20.0 {
        didSet { if fontSize != oldValue { setupHostingController() } }
    }
    
    var borderWidth: CGFloat = 0.0 {
        didSet { if borderWidth != oldValue { setupHostingController() } }
    }
    
    var borderColor: UIColor = .clear {
        didSet { if borderColor != oldValue { setupHostingController() } }
    }
    
    var fontName: String = "PingFangTC-Semibold" {
        didSet { if fontName != oldValue { setupHostingController() } }
    }
    
    var wordTimings: [Double]?
    var wordDurations: [Double]?
    
    /// The style of animation to perform.
    var style: TextAnimationStyle = .popWord {
        didSet { if style != oldValue { setupHostingController() } }
    }
    
    /// Duration per word (only used when `isDemo` is false).
    var wordDuration: Double = 0.25
    
    /// If true, the animation will restart automatically after completion.
    var isDemo: Bool = true
    
    /// The highlight color used for highlight styles.
    var highlightColor: UIColor = .yellow {
        didSet { if highlightColor != oldValue { setupHostingController() } }
    }
    
    var fontColor: UIColor = .white {
        didSet { if fontColor != oldValue { setupHostingController() } }
    }
    
    var shadowcolor: UIColor = .white {
        didSet { if shadowcolor != oldValue { setupHostingController() } }
    }
    
    // MARK: - Internal State
    private let driver = AnimationDriver()
    private var displayLink: CADisplayLink?
    private weak var targetLabel: UILabel?
    private var startTime: CFTimeInterval?
    
    
    // UIHostingController holds the SwiftUI view and is embedded in the UIKit hierarchy
    private var hostingController: UIHostingController<AnimatedTextView>?
    
    // MARK: - Initialization
    /**
     Initializes the animator with the target UILabel.
        
     The animator will use the label's font, color, and frame.
     - Parameter label: The UILabel whose style properties will be used and whose superview will host the animation.
     */
    init(targetLabel label: UILabel) {
        self.targetLabel = label
    }
    
    // MARK: - Public Control Methods
      
    /// Sets up the UIHostingController and prepares the animation.
    private func setupHostingController() {
        guard let label = targetLabel else { return }
        
        // 1. Destroy old hosting controller to remove old animation view
        hostingController?.view.removeFromSuperview()
        hostingController = nil
        
        label.isHidden = true
        
        // 2. Determine colors and font from the UILabel
        let fontColor = Color(fontColor)
        let highlight = Color(highlightColor)
        let textshadowColor = Color(shadowcolor)
        
        // 3. Create the new SwiftUI view
        let animatedView = AnimatedTextView(
            text: text,
            style: style,
            wordDuration: wordDuration,
            isDemo: isDemo,
            wordFontName: fontName,
            fontSize: fontSize,
            wordColor: fontColor,
            highlightColor: highlight,
            borderWidth: borderWidth,
            borderColor: Color(uiColor: borderColor),
            shadowColor: textshadowColor,
            driver: driver
        )
        
        // 4. Create the new hosting controller
        let newHC = UIHostingController(rootView: animatedView)
        newHC.view.backgroundColor = .clear // Ensure the background is transparent
        
        print("[\(Date())] 🟢 SETUP: New HostingController created for style: \(style).")
        
        // 5. Add it to the label's container view
        label.superview?.addSubview(newHC.view)
        hostingController = newHC
        
        // 6. Constraints: Position the hosting view exactly over the UILabel's frame
        newHC.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            newHC.view.leadingAnchor.constraint(equalTo: label.leadingAnchor),
            newHC.view.trailingAnchor.constraint(equalTo: label.trailingAnchor),
            newHC.view.topAnchor.constraint(equalTo: label.topAnchor),
            newHC.view.bottomAnchor.constraint(equalTo: label.bottomAnchor),
        ])
        
    }
    
    /// Starts or restarts the animation sequence.
    func startAnimation() {
        if hostingController == nil {
            setupHostingController()
        }
        
        print("[\(Date())] 🔄 START: Animation starting/restarting. isDemo: \(isDemo).")
        
        // Stop any currently running animation loop
        if displayLink != nil {
            stopAnimation()
        }
        
        // Reset the time for the AnimationDriver
        driver.reset()
        startTime = CACurrentMediaTime()
        
        if isDemo {
            setupDisplayLink()
        }
        
        print("[\(Date())] ✅ START: Animation sequence fully restarted.")
    }
    
    /// Stops the animation and cleans up the timer.
    func stopAnimation() {
        print("[\(Date())] 🛑 STOP: DisplayLink invalidating.")
        
        displayLink?.invalidate()
        displayLink = nil
        startTime = nil
        driver.reset()
    }
    
    func updateAnimation(
        to time: Double,
        style: TextAnimationStyle,
        fontName: String,
        text: String,
        wordDuration: Double,
        highlightColor: UIColor?,
        fontColor: UIColor?,
        timings: [Double]?,
        durations: [Double]?,
        fontSize: CGFloat,
        borderWidth: CGFloat,
        borderColor: UIColor
    ) {
        let fontChanged = (self.fontName != fontName) || (self.text != text) || (fontColor != fontColor)
        let styleChanged = self.style != style
        let appearanceChanged = (self.fontSize != fontSize) || (self.borderWidth != borderWidth) || (self.borderColor != borderColor)
        
        // 1. Reconfigure the animator properties (crucial for ensuring the view is ready)
        self.wordTimings = timings
        self.wordDurations = durations
        
        self.style = style
        self.text = text
        self.fontName = fontName
        self.wordDuration = wordDuration
        
        self.fontSize = fontSize
        self.borderWidth = borderWidth
        self.borderColor = borderColor
        
        if let hColor = highlightColor {
            self.highlightColor = hColor
        }
        if let fColor = fontColor {
            self.fontColor = fColor
        }
        if let timings = timings {
            self.driver.wordTimings = timings
        }
        if let durations = durations {
            self.driver.wordDurations = durations
        }
        
        if fontChanged || styleChanged || appearanceChanged {
            print("[\(Date())] ♻️ REBUILD: Recreating HostingController due to data change.")
            setupHostingController()
        }
        
        driver.update(time: time)
        
        // 2. The core animation logic
        if isLayoutBasedStyle(style: style) {
            let currentWordIndex = Int(time / wordDuration)
            let totalWords = words.count
            
            if currentWordIndex < totalWords {
                self.driver.animatedIndex = currentWordIndex
            }
        } else {
            if displayLink != nil {
                stopAnimation()
            }
        }
    }
    
    // MARK: - CADisplayLink Management
    private func setupDisplayLink() {
        let link = CADisplayLink(target: self, selector: #selector(updateTime))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }
    
    @objc private func updateTime(link: CADisplayLink) {
        guard let start = startTime else {
            startTime = CACurrentMediaTime()
            return
        }
        
        let currentTime = link.timestamp - start
        let totalWordCount = words.count // Must be defined by text.split
        let demoLoopBuffer: Double = 0.3
        
        // The base time unit per word (0.3 for demo, wordDuration for video sync)
        let baseTimeDuration = wordDuration > 0 ? wordDuration : 0.3
        
        // --- Determine the actual duration the word animation takes ---
        // This resolves the mismatch with the hardcoded 0.30s in SwiftUI fade/pop/slide animations
        let wordAnimationDuration: Double
        switch style {
        case .popWord, .shrinkPopWord:
            wordAnimationDuration = isDemo ? 0.25 : wordDuration
        case .fadeWord, .slideUpWord, .slideDownWord:
            wordAnimationDuration = isDemo ? 0.35 : wordDuration
        case .typewriterNormal, .typewriterUnderScoreCurser:
            wordAnimationDuration = baseTimeDuration
        default:
            wordAnimationDuration = baseTimeDuration
        }
        
        // --- 1. Handle Demo Mode (All Styles) ---
        if isDemo {
            driver.update(time: currentTime)
            
            let isLayout = isLayoutBasedStyle(style: style)
            
            if isLayout {
                // Calculate index based on time
                let currentWordIndex = Int(floor(currentTime / baseTimeDuration))
                if currentWordIndex < totalWordCount {
                    if currentWordIndex != driver.animatedIndex {
                        driver.animatedIndex = currentWordIndex
                    }
                }
            }
            
            // B. Determine Completion Time for Looping
            let totalTime: Double
            switch style {
            case .typewriterNormal, .typewriterUnderScoreCurser:
                // Typewriter styles use char count
                let totalCharCount = text.replacingOccurrences(of: " ", with: "").count
                let charTime = baseTimeDuration / 3.0
                totalTime = Double(totalCharCount) * charTime
            default:
                // All other styles (Layout and Time-Based) use word count * the specific wordAnimationDuration
                totalTime = Double(totalWordCount) * wordAnimationDuration
            }
            
            // C. Handle Looping
            let isComplete = currentTime >= totalTime + demoLoopBuffer
            
            if isComplete {
                print("[\(Date())] 🔁 LOOP: Condition met. Restarting animation at time \(currentTime). Total words: \(totalWordCount). Expected duration: \(totalTime + demoLoopBuffer)")
                startAnimation()
            }
            
        }
        // --- 2. Handle Video Sync Mode (for non-layout styles not using external updateAnimation) ---
        else if !isLayoutBasedStyle(style: style) {
            // If CADisplayLink is running in non-demo mode, it means it was started for video sync
            driver.update(time: currentTime)
            
            // Note: The completion logic is usually handled by an external call to stopAnimation()
            // when the video ends, but we keep the termination logic here for safety.
            
            let totalTime: Double
            switch style {
            case .typewriterNormal, .typewriterUnderScoreCurser:
                let totalCharCount = text.replacingOccurrences(of: " ", with: "").count
                let charTime = baseTimeDuration / 3.0
                totalTime = Double(totalCharCount) * charTime
            default:
                totalTime = Double(totalWordCount) * wordAnimationDuration
            }
            
            let isComplete = currentTime >= totalTime + demoLoopBuffer
            
            if isComplete && !isDemo {
                stopAnimation()
            }
        }
    }
    
    // MARK: - Utility & Cleanup
    private var words: [String] { text.split(separator: " ").map(String.init) }
    
    private func isLayoutBasedStyle(style: TextAnimationStyle) -> Bool {
        return style == .highlighByUnderline || style == .highlighByBackground
    }
    
    deinit {
        // Essential for cleanup to prevent crashes when the manager is released
        stopAnimation()
        hostingController?.view.removeFromSuperview()
    }
}

// MARK: - Helper Extension for Font Conversion
private extension UIFont {
    /// Converts a UIKit UIFont to a SwiftUI Font.
    func toSwiftUI() -> Font {
        return Font(self as CTFont)
    }
}
