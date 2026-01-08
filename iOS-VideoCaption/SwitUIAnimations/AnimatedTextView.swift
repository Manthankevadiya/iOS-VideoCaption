//
//  AnimatedTextView.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 02/12/25.
//


import SwiftUI
import Combine

/// Drives the animation based on time for all styles.
class AnimationDriver: ObservableObject {
    @Published var time: Double = 0
    @Published var animatedIndex: Int = 0
    
    @Published var wordTimings: [Double] = []
    @Published var wordDurations: [Double] = []
    
    func reset() {
        DispatchQueue.main.async {
            self.time = 0
            self.animatedIndex = 0
        }
    }
    
    func update(time: Double) {
        self.time = time
    }
}

// MARK: - 2. SwiftUI AnimatedTextView
// -----------------------------------------------------

struct AnimatedTextView: View {
    let text: String
    let style: TextAnimationStyle
    let wordDuration: Double
    let isDemo: Bool
    
    let wordFontName: String
    let fontSize: CGFloat
    let wordColor: Color
    let highlightColor: Color
    
    let borderWidth: CGFloat
    let borderColor: Color
    let shadowColor: Color
    
    @ObservedObject var driver: AnimationDriver
    
    private var words: [String] { text.split(separator: " ").map(String.init) }
    private var demoSpeed: Double { 0.3 }
    private var timing: Double { isDemo ? demoSpeed : wordDuration }
    
    @State private var wordFrames: [Int: CGRect] = [:]
    @State private var lastReadPrefs: [Int: CGRect] = [:]
    
    private var currentFont: Font {
        if wordFontName.isEmpty {
            return .system(size: fontSize, weight: .bold)
        }
        return .custom(wordFontName, size: fontSize)
    }
    
    private var wordSpacing: CGFloat {
        // A standard typographic rule is 20-25% of the font size
        return fontSize * 0.25
    }
    
    private func animationDuration(for index: Int) -> Double {
        if index >= 0 && index < driver.wordDurations.count {
            let actualDuration = driver.wordDurations[index]
            return min(actualDuration, 0.3)
        }
        return 0.35
    }
    
    private func appearTime(for index: Int) -> Double {
        // ✅ FIX: Force calculated timing in Demo mode
        // This ensures 'getInterpolatedFrame' subtracts numbers that make sense.
        if isDemo {
            return Double(index) * timing
        }
        
        if index >= 0 && index < driver.wordTimings.count {
            return driver.wordTimings[index]
        }
        return Double(index) * timing
    }
    
    private var currentActiveIndex: Int {
        // ✅ FIX: In Demo mode, ignore wordTimings and use the explicit index
        if isDemo {
            return min(max(0, driver.animatedIndex), words.count - 1)
        }
        
        if !driver.wordTimings.isEmpty {
            let timings = driver.wordTimings
            
            if let first = timings.first, driver.time < first { return 0 }
            
            var activeI = 0
            for (i, start) in timings.enumerated() {
                if driver.time >= start {
                    activeI = i
                } else {
                    break
                }
            }
            return min(activeI, words.count - 1)
        }
        return min(max(0, driver.animatedIndex), words.count - 1)
    }
    
    var body: some View {
        Group {
            switch style {
            case .normal:                        normalLineAnimation()
            case .popWord:                       popAnimation()
            case .shrinkPopWord:                 shrinkPopAnimation()
            case .fadeWord:                      fadeAnimation()
            case .slideUpWord:                   slideUpAnimation()
            case .slideDownWord:                 slideDownAnimation()
            case .typewriterNormal:              typewriterNormalBarAnimation()
            case .typewriterUnderScoreCurser:    typewriterUnderscoreAnimation()
            case .highlighSingleWord:            instantHighlightAnimation()
            case .highlighTrail:                 trailingHighlightAnimation()
            case .highlighByUnderline:           underlineHighlightAnimation()
            case .highlighByBackground:          corneredBackgroundAnimation()
            }
        }
        .font(currentFont)
        .foregroundColor(wordColor)
        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
        .frame(maxWidth: .infinity, alignment: .center) 
    }
}

// MARK: - AnimatedTextView Extensions (Style Implementations)
// -----------------------------------------------------------

// --- Normal - Pop & Shrink Animations (Word-based) ---
extension AnimatedTextView {
    func normalLineAnimation() -> some View {
        Text(text)
            .textStroke(color: borderColor, width: borderWidth)
    }
    
    func popAnimation() -> some View {
        HStack(spacing: wordSpacing) {
            ForEach(words.indices, id: \.self) { i in
                let appear = appearTime(for: i)
                let wordDuration = animationDuration(for: i)
                
                let p = max(0, min(1, (driver.time - appear) / wordDuration))
                
                Text(words[i])
                    .textStroke(color: borderColor, width: borderWidth)
                    .scaleEffect(0.01 + 0.99 * p)
                    .opacity(p)
            }
        }
    }
    
    func shrinkPopAnimation() -> some View {
        HStack(spacing: wordSpacing) {
            ForEach(words.indices, id: \.self) { i in
                let appear = appearTime(for: i)
                let wordDuration = animationDuration(for: i)
                
                let p = max(0, min(1, (driver.time - appear) / wordDuration))
                
                Text(words[i])
                    .textStroke(color: borderColor, width: borderWidth)
                    .scaleEffect(2.0 - 1.0 * p)
                    .opacity(p)
            }
        }
    }
}

// --- Fade & Slide Animations (Word-based) ---
extension AnimatedTextView {
    func fadeAnimation() -> some View {
        HStack(spacing: wordSpacing) {
            ForEach(words.indices, id: \.self) { i in
                let appear = appearTime(for: i)
                let wordDuration = animationDuration(for: i)
                
                let p = max(0, min(1, (driver.time - appear) / wordDuration))
                
                Text(words[i])
                    .textStroke(color: borderColor, width: borderWidth)
                    .opacity(p)
            }
        }
    }
    
    func slideUpAnimation() -> some View {
        HStack(spacing: wordSpacing) {
            ForEach(words.indices, id: \.self) { i in
                let appear = appearTime(for: i)
                let wordDuration = animationDuration(for: i)
                
                let p = max(0, min(1, (driver.time - appear) / wordDuration))
                
                Text(words[i])
                    .textStroke(color: borderColor, width: borderWidth)
                    .offset(y: 20 - 20 * p)
                    .opacity(p)
            }
        }
    }
    
    func slideDownAnimation() -> some View {
        HStack(spacing: wordSpacing) {
            ForEach(words.indices, id: \.self) { i in
                let appear = appearTime(for: i)
                let wordDuration = animationDuration(for: i)
                
                let p = max(0, min(1, (driver.time - appear) / wordDuration))
                
                Text(words[i])
                    .textStroke(color: borderColor, width: borderWidth)
                    .offset(y: -20 + 20 * p)
                    .opacity(p)
            }
        }
    }
}

// MARK: - Typewriter Helpers (Precise Sync)
private extension AnimatedTextView {
    
    func typewriterText() -> String {
        if isDemo {
            let totalChars = text.count
            let demoDuration = 1.5
            let progress = min(1.0, max(0.0, driver.time / demoDuration))
            let charIndex = Int(Double(totalChars) * progress)
            return String(text.prefix(charIndex))
        }
        
        let words = self.words
        let timings = driver.wordTimings
        let durations = driver.wordDurations
        
        guard words.count == timings.count, words.count == durations.count else {
            return text
        }
        
        var completedString = ""
        
        for i in 0..<words.count {
            let word = words[i]
            let startTime = timings[i]
            let duration = durations[i]
            let endTime = startTime + duration
            
            // Fix: Enforce a "Max Duration per Character"
            // e.g., never take more than 0.1s per character, even if the word duration is huge.
            let maxCharDuration = 0.1
            let calculatedDuration = Double(word.count) * maxCharDuration
            
            // Use the SHORTER of:
            // 1. The actual audio duration (minus a small buffer to finish early)
            // 2. The calculated "natural typing" duration
            let safeBuffer = 0.05 // Finish 50ms early to avoid cutoff
            let activeDuration = min(duration - safeBuffer, calculatedDuration)
            
            // Ensure we don't divide by zero or have negative duration
            let finalTypingDuration = max(0.01, activeDuration)
            
            let prefixSpace = (i > 0) ? " " : ""
            
            // Global Check: If we are past the SAFETY buffer, force show full word
            if driver.time >= (endTime - safeBuffer) {
                completedString += prefixSpace + word
            }
            else if driver.time >= startTime {
                // We are actively typing
                let timeInWord = driver.time - startTime
                
                // Progress based on our calculated "fast" duration
                let progress = min(1.0, timeInWord / finalTypingDuration)
                
                completedString += prefixSpace
                let charCount = Int(Double(word.count) * progress)
                let partialWord = String(word.prefix(charCount))
                
                completedString += partialWord
                return completedString
            } else {
                // Future word
                return completedString
            }
        }
        
        return completedString
    }
    
    func shouldBlink() -> Bool {
        let allChars = Array(text.replacingOccurrences(of: " ", with: "\u{200b} "))
        
        guard !allChars.isEmpty else { return false }
        
        // Determine if typing is finished
        let isFinished: Bool
        if isDemo || driver.wordTimings.isEmpty {
            // Calculate calculated time per character
            let totalChars = Double(allChars.count)
            let totalWords = Double(words.count)
            
            // ✅ FIX 2: Prevent division by zero if words or chars are 0
            let rawCharTime = isDemo ? (timing / 3.0) : (timing * totalWords / (totalChars > 0 ? totalChars : 1))
            
            // ✅ FIX 3: Ensure charTime is a safe, positive number
            let charTime = rawCharTime > 0.0001 ? rawCharTime : 0.05
            
            // Now safe to divide
            let visibleCount = Int(driver.time / charTime)
            isFinished = visibleCount >= allChars.count
            
        } else {
            // Precise mode: check if time is past the end of the last word
            if let lastStart = driver.wordTimings.last, let lastDur = driver.wordDurations.last {
                isFinished = driver.time >= (lastStart + lastDur)
            } else {
                isFinished = true
            }
        }
        
        // Standard blink rate (0.3s)
        let shouldShowCursor = Int(driver.time / 0.3) % 2 == 0
        
        // Blink only if we haven't finished typing yet (or always blink if you prefer)
        return !isFinished && shouldShowCursor
    }
}

// --- Typewriter Animations (Character-based) ---
extension AnimatedTextView {
    func typewriterNormalBarAnimation() -> some View {
        let displayedText = typewriterText()
        let showCursor = shouldBlink()
        
        // Define the cursor character
        let cursorChar = "|"
        
        return ZStack(alignment: .center) {
            // ------------------------------------------------
            // 1. INVISIBLE ANCHOR (Defines the full box size)
            // ------------------------------------------------
            HStack(spacing: 0) {
                Text(text) // Full text
                    .font(currentFont)
                    .textStroke(color: borderColor, width: borderWidth)
                    .foregroundColor(.clear)
                
                Text(cursorChar) // Cursor Placeholder
                    .font(currentFont)
                    .textStroke(color: borderColor, width: borderWidth)
                    .foregroundColor(.clear) // Invisible
            }
            
            // ------------------------------------------------
            // 2. VISIBLE CONTENT (Overlays exactly)
            // ------------------------------------------------
            HStack(spacing: 0) {
                Text(displayedText) // Typing text
                    .font(currentFont)
                    .textStroke(color: borderColor, width: borderWidth)
                // Important: Allow it to take up space naturally
                    .fixedSize(horizontal: true, vertical: false)
                
                Text(cursorChar) // Real Cursor
                    .font(currentFont)
                    .textStroke(color: borderColor, width: borderWidth)
                    .opacity(showCursor ? 1 : 0)
            }
        }
        // Force the ZStack to expand to the full available width of the parent (the Label)
        // and center the content within that space.
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    func typewriterUnderscoreAnimation() -> some View {
        let displayedText = typewriterText()
        // Determine cursor visibility: True if blinking ON, or False if blinking OFF
        // BUT we always render the character, just change opacity.
        let showCursor = shouldBlink()
        
        return ZStack(alignment: .center) {
            // 1. Invisible Anchor (Full Text + Cursor Placeholder)
            // We append the cursor char so the box is always wide enough for it.
            Text(text + "_")
                .font(currentFont)
                .textStroke(color: borderColor, width: borderWidth)
                .foregroundColor(.clear)
                .multilineTextAlignment(.center)
            
            // 2. Visible Content
            // We construct the string.
            HStack(spacing: 0) {
                Text(displayedText)
                    .font(currentFont)
                    .textStroke(color: borderColor, width: borderWidth)
                
                // Cursor is its own view so we can fade it without reflowing text
                Text("_")
                    .font(currentFont)
                    .textStroke(color: borderColor, width: borderWidth)
                    .opacity(showCursor ? 1 : 0) // Fade in/out instead of add/remove
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// --- Highlight Animations (Timing-based) ---
extension AnimatedTextView {
    func instantHighlightAnimation() -> some View {
        HStack(spacing: wordSpacing) {
            ForEach(words.indices, id: \.self) { i in
                let appear = appearTime(for: i)
                let fullDuration = animationDuration(for: i)
                
                let p = (driver.time - appear) / fullDuration
                let isHighlightActive = p > 0 && p < 1
                let currentColor = isHighlightActive ? highlightColor : wordColor
                
                Text(words[i])
                    .textStroke(color: borderColor, width: borderWidth)
                    .foregroundColor(currentColor)
            }
        }
    }
    
    func trailingHighlightAnimation() -> some View {
        HStack(spacing: wordSpacing) {
            ForEach(words.indices, id: \.self) { i in
                let appear = appearTime(for: i)
                
                let isHighlighted = driver.time >= appear
                let currentHighlightColor = isHighlighted ? highlightColor : wordColor
                
                Text(words[i])
                    .textStroke(color: borderColor, width: borderWidth)
                    .foregroundColor(currentHighlightColor)
            }
        }
    }
}

// --- Highlight Animations (Layout-based) ---
// (Preference Keys remain unchanged)
struct WordBoundsKey: PreferenceKey {
    static var defaultValue: [Int: Anchor<CGRect>] = [:]
    static func reduce(value: inout [Int: Anchor<CGRect>], nextValue: () -> [Int: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    func wordIndex(_ index: Int) -> some View {
        self.anchorPreference(key: WordBoundsKey.self, value: .bounds) {
            [index: $0]
        }
    }
}

struct WordFramesKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - Layout Based Highlights (Export Safe with Sliding)
extension AnimatedTextView {
    
    // Helper to calculate the "Sliding" Frame
    private func getInterpolatedFrame(frames: [Int: CGRect], activeIndex: Int) -> CGRect? {
        guard let currentRect = frames[activeIndex] else { return nil }
        
        // If it's the first word, no slide needed.
        if activeIndex == 0 { return currentRect }
        
        if let prevRect = frames[activeIndex - 1] {
            
            // --- NEW LOGIC: Calculate Progress directly from Time Modulo ---
            let p: Double
            
            if isDemo {
                // In Demo mode, time is linear: 0.0 -> 0.3 -> 0.6
                // The "progress" into the current word is simply the fractional part of the current interval.
                
                // 1. How far are we into the current word's slot?
                // e.g. Time = 0.35, Word Duration = 0.3. Offset = 0.05
                // However, driver.time might be 0.35, but activeIndex might be 1.
                // start time of word 1 is 0.3.
                
                let wordStartTime = Double(activeIndex) * timing // e.g. 0.3
                let offset = driver.time - wordStartTime
                
                // 2. Define Slide Duration (e.g. half the word duration)
                let slideDur = timing * 0.5 // 0.15s
                
                if offset <= 0 {
                    p = 0
                } else if offset >= slideDur {
                    p = 1
                } else {
                    p = offset / slideDur
                }
                
                // DEBUG PRINT (Uncomment to see if time is actually moving)
                // print("Demo Slide: Index \(activeIndex), Time: \(driver.time), P: \(p)")
                
            } else {
                // Video Mode Logic (unchanged)
                let startTime = appearTime(for: activeIndex)
                let slideDuration = min(0.25, animationDuration(for: activeIndex))
                let timeIntoCurrentWord = driver.time - startTime
                p = max(0, min(1, timeIntoCurrentWord / slideDuration))
            }
            
            // Apply Easing
            let t = CGFloat(p * p * (3 - 2 * p))
            
            let x = prevRect.minX + (currentRect.minX - prevRect.minX) * t
            let y = prevRect.minY + (currentRect.minY - prevRect.minY) * t
            let w = prevRect.width + (currentRect.width - prevRect.width) * t
            let h = prevRect.height + (currentRect.height - prevRect.height) * t
            
            return CGRect(x: x, y: y, width: w, height: h)
        }
        
        return currentRect
    }
    
    private func layoutBasedHighlightContent(
        overlay: @escaping (GeometryProxy, [Int: CGRect], Int) -> some View,
        highlightOnTop: Bool
    ) -> some View {
        
        let textView = HStack(spacing: wordSpacing) {
            ForEach(words.indices, id: \.self) { i in
                Text(words[i])
                    .textStroke(color: borderColor, width: borderWidth)
                    .foregroundColor(wordColor)
                    .wordIndex(i)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(borderWidth * 2 + 10)
        
        return ZStack(alignment: .topLeading) {
            textView
        }
        .overlayPreferenceValue(WordBoundsKey.self) { anchors in
            GeometryReader { geo in
                let frames = anchors.compactMapValues { anchor in
                    geo[anchor]
                }
                
                let activeIndex = currentActiveIndex
                let highlightView = overlay(geo, frames, activeIndex)
                
                Color.clear
                    .preference(key: WordFramesKey.self, value: frames)
                
                if highlightOnTop {
                    highlightView
                } else {
                    ZStack {
                        highlightView
                        textView
                    }
                }
            }
        }
        .onPreferenceChange(WordFramesKey.self) { resolvedFrames in
            lastReadPrefs = resolvedFrames
        }
    }
    
    func underlineHighlightAnimation() -> some View {
        layoutBasedHighlightContent(overlay: { geo, frames, index in
            // Use the sliding logic
            let slidingRect = getInterpolatedFrame(frames: frames, activeIndex: index)
            
            let thickness = max(4, fontSize * 0.1)
            let radius = thickness / 2
            
            return Group {
                if let rect = slidingRect {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(highlightColor)
                        .frame(width: rect.width, height: thickness)
                        // Position based on the sliding rect's bottom edge
                        .position(x: rect.midX, y: rect.maxY + 3)
                } else {
                    EmptyView()
                }
            }
        }, highlightOnTop: true)
    }
    
    func corneredBackgroundAnimation() -> some View {
        layoutBasedHighlightContent(overlay: { geo, frames, index in
            // Use the sliding logic
            let slidingRect = getInterpolatedFrame(frames: frames, activeIndex: index)
            let dynamicRadius = fontSize * 0.5
            
            return Group {
                if let rect = slidingRect {
                    RoundedRectangle(cornerRadius: dynamicRadius)
                        .fill(highlightColor.opacity(0.6))
                        .frame(width: rect.width + 10, height: rect.height + 4)
                        // Position centered on the sliding rect
                        .position(x: rect.midX, y: rect.midY)
                } else {
                    EmptyView()
                }
            }
        }, highlightOnTop: false)
    }
}
