//
//  AnimationExtension.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 04/12/25.
//

import UIKit
import SwiftUI
import ObjectiveC

extension UILabel {
    // Key for associated object to store the animator instance
    private struct AssociatedKeys {
        static var animatorManager: UInt8 = 0
    }
    
    /// The associated UILabelAnimator instance for this label.
    var animator: UILabelAnimator? {
        get {
            // Retrieve the associated object
            return objc_getAssociatedObject(self, &AssociatedKeys.animatorManager) as? UILabelAnimator
        }
        set {
            // Set (or replace) the associated object
            objc_setAssociatedObject(self, &AssociatedKeys.animatorManager, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

// MARK: - 3. Public UILabel Wrapper Function
extension UILabel {
    
    // NOTE: Ensure your UILabel.animator property is defined and accessible here!
    
    /**
     The master function to drive the animation based on dynamic, time-synced caption data.
     This method applies the custom speed adjustment logic and calls the animator.
     */
    func updateAnimationFromLine(
        rawTime: Double,
        lineStartTime: Double,
        text: String,
        fontName: String = "",
        wordCount: Double,
        lineDuration: Double,
        style: TextAnimationStyle,
        highlightColor: UIColor? = nil,
        fontColor: UIColor? = nil,
        timings: [Double]?,
        durations: [Double]?,
        fontSize: CGFloat? = nil,
        borderWidth: CGFloat = 0.0,
        borderColor: UIColor = .clear
    ) {
        // --- 1. Ensure/Create Animator ---
        if animator == nil {
            animator = UILabelAnimator(targetLabel: self)
            animator?.fontName = self.font.fontName
            animator?.fontSize = self.font.pointSize
        }
        let animator = self.animator!
        
        // --- 2. Calculate Animation Time Relative to Line Start ---
        let relativeTime = rawTime - lineStartTime
        
        // --- 3. Custom Speed Adjustment Logic ---
        let minEffectiveDuration: Double = 0.5
        let maxEffectiveDuration: Double = 5.0
        
        var adjustedTime = relativeTime
        var totalEffectiveDuration = lineDuration
        
        if lineDuration < minEffectiveDuration {
            // SLOW DOWN: Make short lines last longer
            let speedFactor = lineDuration / minEffectiveDuration
            adjustedTime = relativeTime * speedFactor
            totalEffectiveDuration = minEffectiveDuration
            
        } else if lineDuration > maxEffectiveDuration {
            // SPEED UP: Compress long lines
            let speedFactor = lineDuration / maxEffectiveDuration
            adjustedTime = relativeTime / speedFactor
            totalEffectiveDuration = maxEffectiveDuration
        }
        
        // Calculate the effective duration per word for the animator to use
        let effectiveWordDuration = totalEffectiveDuration / wordCount
        
        // --- 4. Call the Animator (using the comprehensive signature) ---
        animator.updateAnimation(
            to: adjustedTime, // Use the adjusted time
            style: style,
            fontName: fontName,
            text: text,
            wordDuration: effectiveWordDuration,
            highlightColor: highlightColor,
            fontColor: fontColor,
            timings: timings,
            durations: durations,
            fontSize: fontSize ?? animator.fontSize,
            borderWidth: borderWidth,
            borderColor: borderColor
        )
    }
}

extension UILabel {
    
    /**
     Stops any existing animation on the label and starts a new one using the SwiftUI bridge.
     
     - Parameters:
     - text: The content to animate.
     - style: The desired animation style.
     - highlightColor: The color to use for highlighting (defaults to yellow if nil).
     - isDemo: If true, the animation loops (restarts on completion).
     - wordDuration: Custom duration per word/character step when not in demo mode.
     */
    func animateText(
        _ text: String,
        style: TextAnimationStyle,
        highlightColor: UIColor? = nil,
        isDemo: Bool,
        wordDuration: Double = 0.25,
        fontSize: CGFloat? = nil,
        borderWidth: CGFloat = 0.0,
        borderColor: UIColor = .clear,
        fontName: String = "",
        fontColor: UIColor? = nil
    ) {
        // Stop any currently running animation on this label
        animator?.stopAnimation()
        
        // 1. Ensure an animator exists, or create a new one.
        if animator == nil {
            // The animator is only created once per UILabel instance
            animator = UILabelAnimator(targetLabel: self)
            animator?.fontName = self.font.fontName
            animator?.fontSize = self.font.pointSize
        }
        
        // 2. Configure the animator instance.
        let animator = self.animator!
        animator.text = text
        animator.fontName = fontName
        animator.style = style
        animator.isDemo = isDemo
        animator.wordDuration = wordDuration
        
        if let fs = fontSize { animator.fontSize = fs }
        animator.borderWidth = borderWidth
        animator.borderColor = borderColor
        
        if let hColor = highlightColor {
            animator.highlightColor = hColor
        }
        
        if let fColor = fontColor {
            animator.fontColor = fColor
        }
        
        // 3. Start the animation.
        animator.startAnimation()
    }
    /**
     Stops any current animation and restores the label to its original state.
     */
    func normalTextedLabel() {
        if animator != nil {
            animator?.stopAnimation()
        }
        self.text = ""
    }
}

extension View {
    func textStroke(color: Color, width: CGFloat) -> some View {
        guard width > 0 else { return AnyView(self) }
        
        // Simulating a stroke using 4 shadows.
        // This is the standard performant way in SwiftUI for captions.
        return AnyView(self
            .shadow(color: color, radius: 0, x: -width, y: -width)
            .shadow(color: color, radius: 0, x: width, y: -width)
            .shadow(color: color, radius: 0, x: -width, y: width)
            .shadow(color: color, radius: 0, x: width, y: width)
        )
    }
}
