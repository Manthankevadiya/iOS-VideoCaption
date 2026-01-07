//
//  CaptionFormatter.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 25/11/25.
//

import Foundation
import UIKit

/**
 Pre-processes a flat list of timed words into structured, line-by-line captions.
 */
class CaptionFormatter {
    
    // Default words per line, can be read from Core Data/project settings
    private let wordsPerLine: Int
    private let maxCaptionWidth: CGFloat
    private let font: UIFont
    
    // The final array of formatted lines
    private(set) var captionLines: [CaptionLine] = []
    
    init(wordsPerLine: Int = 4, maxCaptionWidth: CGFloat, font: UIFont) {
        self.wordsPerLine = wordsPerLine
        self.maxCaptionWidth = maxCaptionWidth
        self.font = font
    }
    
    func formatCaptions(from timedWords: [TimedWord]) {
        guard !timedWords.isEmpty else {
            self.captionLines = []
            return
        }
        
        var currentWords: [TimedWord] = []
        var formattedLines: [CaptionLine] = []
        
        for word in timedWords {
            
            // --- 1. Check for Line Break Condition BEFORE adding the current word ---
            
            // Check A: If adding this word will make the line too long (respecting max width).
            let prospectiveLineText = (currentWords + [word]).map { $0.word }.joined(separator: " ")
            let textWidth = prospectiveLineText.size(withAttributes: [.font: self.font]).width
            let isLineTooWide = textWidth > self.maxCaptionWidth

            // Check B: If adding this word will exceed the specified word limit.
            let isLineExceedingWordLimit = currentWords.count == self.wordsPerLine

            // Check C: If the PREVIOUS word ended a sentence (punctuation check).
            let previousWordEndedSentence = currentWords.last?.word.contains(where: { $0 == "." || $0 == "?" || $0 == "!" || $0 == "\n" }) ?? false
            
            
            // --- 2. Decide if we MUST finalize the current line ---
            if isLineTooWide || isLineExceedingWordLimit || previousWordEndedSentence {
                
                // We finalize the current line ONLY IF it's not empty.
                if !currentWords.isEmpty {
                    finalizeLine(words: currentWords, &formattedLines)
                    currentWords = []
                }
                
                // If the line was empty, or just finalized, the current word will be the first word of the new line.
            }
            
            // --- 3. Add the current word to the current (or new) line ---
            currentWords.append(word)
        }
        
        // 4. Finalize any remaining words
        if !currentWords.isEmpty {
            finalizeLine(words: currentWords, &formattedLines)
        }
        
        self.captionLines = formattedLines
        print("Formatted \(formattedLines.count) caption lines.")
    }
    
    /**
     Helper to create and append a CaptionLine.
     */
    private func finalizeLine(words: [TimedWord], _ formattedLines: inout [CaptionLine]) {
        guard let firstWord = words.first,
              let lastWord = words.last else { return }
        
        let lineText = words.map { $0.word }.joined(separator: " ")
        
        let line = CaptionLine(
            words: words,
            text: lineText,
            startTime: firstWord.startTime,
            endTime: lastWord.startTime + lastWord.duration
        )
        
        formattedLines.append(line)
    }
    
    /**
     Finds the correct CaptionLine to display for a given time.
     */
    func captionLine(for time: Double) -> CaptionLine? {
        return self.captionLines.first { line in
            return time >= line.startTime && time <= line.endTime
        }
    }
}
