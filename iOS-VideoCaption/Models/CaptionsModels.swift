//
//  Captions.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 10/11/25.
//

import UIKit
import CoreData

struct ExportConfiguration {
    let videoURL: URL
    let style: TextAnimationStyle
    
    // Caption timing/layout
    let captionFormatter: CaptionFormatter
    
    // Appearance
    let fontName: String
    let fontSize: CGFloat
    let textColor: UIColor
    let highlightColor: UIColor
    let borderColor: UIColor
    let borderWidth: CGFloat
    
    // Timing helper (used only when precise timings are not available)
    let defaultWordDuration: Double
    
    // Layout mapping
    let referenceCanvasSize: CGSize
    let uiCaptionFrame: CGRect
}

struct TimedWord: Equatable {
    let word: String
    let startTime: TimeInterval
    var duration: TimeInterval
}

struct CaptionLine {
    let words: [TimedWord]
    let text: String
    let startTime: Double
    let endTime: Double
    
    var effectiveWordDuration: Double {
        guard !words.isEmpty else { return 0 }
        return (endTime - startTime) / Double(words.count)
    }
}

struct CaptionStyleParameters {
    let text: String
    let font: UIFont
    let textColor: UIColor
    let highlightColor: UIColor
    let backgroundColor: UIColor
    let borderColor: UIColor?
}

struct WordSegment {
    let objectID: NSManagedObjectID?
    var text: String
    var start: Double
    var duration: Double
    var end: Double { start + duration }
}
