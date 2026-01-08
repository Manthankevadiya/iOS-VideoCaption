//
//  Enums.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 03/11/25.
//

import UIKit

enum VideoActionType {
    case trim
    case crop
    case compress
    case caption
}

enum HapticFeedbackType {
    case selection
    case success
    case warning
    case error
    case light
    case medium
    case heavy
}

enum EditCaptionType {
    case animationStyle
    case font
    case fontColor
}

enum CaptionColorType {
    case fontColor
    case highlightColor
    case borderColor
    case shadowColor
}

enum TypingAnimationType {
    case box
    case cursor
    case underScore
}

enum TextAnimationStyle: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    
    case normal = "Normal Word"
    case popWord = "Pop Word"
    case shrinkPopWord = "Shrink Pop Word"
    case fadeWord = "Fade Word"
    case slideUpWord = "Slide Up Word"
    case slideDownWord = "Slide Down Word"
    case typewriterNormal = "Typewriter Normal"
    case typewriterUnderScoreCurser = "Typewriter Underscore Cursor"
    case highlighSingleWord = "Instant Highlight"
    case highlighTrail = "Trailing Highlight"
    case highlighByUnderline = "Underline Highlight (Layout-Based)"
    case highlighByBackground = "Background Highlight (Layout-Based)"
}
