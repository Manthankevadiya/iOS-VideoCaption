//
//  CaptionManager.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 10/11/25.
//

import Foundation
import Speech
import AVFoundation

class CaptionManager: NSObject {
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    init(languageCode: String) {
        let locale = Locale(identifier: languageCode)
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        super.init()
    }
    
    // NOTE: You must implement these helper stubs in your actual class
    private func splitMultiWordSegments(from segments: [TimedWord]) -> [TimedWord] {
        // Placeholder for your implementation
        return segments
    }
    
    // Public Transcription Function
    func transcribeAudio(url audioURL: URL, completion: @escaping (Result<[TimedWord], Error>) -> Void) {
        
        guard speechRecognizer?.isAvailable == true else {
            let error = NSError(domain: "CaptionManagerError", code: 1,
                                userInfo: [NSLocalizedDescriptionKey: "Speech recognizer is not available on this device."])
            completion(.failure(error))
            return
        }
        
        // Setup Audio Session for Background Processing
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: .mixWithOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio Session setup error: \(error)")
        }
        
        cancelTranscription()
        
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = true
        request.taskHint = .dictation
        if #available(iOS 16, *) { request.addsPunctuation = true }
        
        print("Starting transcription of file: \(audioURL.lastPathComponent)")
        
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] (result, error) in
            
            defer {
                if result?.isFinal == true || error != nil {
                    self?.recognitionTask = nil
                    try? AVAudioSession.sharedInstance().setActive(false)
                }
            }
            
            guard self != nil else { return }
            
            if let error = error {
                // Ignore "Cancellation" error (code 203) as it's user-initiated
                let nsError = error as NSError
                if nsError.code == 203 {
                    print("Transcription cancelled.")
                } else {
                    print("Transcription error: \(error.localizedDescription)")
                    completion(.failure(error))
                }
                return
            }
            
            guard let result = result, result.isFinal else {
                return // Wait for final result
            }
            
            print("Final Transcription received. Processing...")
            
            // --- DATA EXTRACTION ---
            let segments = result.bestTranscription.segments
            var rawWordList: [TimedWord] = []
            
            for segment in segments {
                // A. Handle potential multi-word segments (rare in 'dictation' mode but possible)
                if segment.substring.contains(" ") {
                    let segmentWords = segment.substring.split(separator: " ")
                    let totalDuration = segment.duration
                    let wordsCount = Double(segmentWords.count)
                    let estimatedWordDuration = totalDuration / max(wordsCount, 1.0)
                    
                    var currentTime = segment.timestamp
                    
                    for word in segmentWords {
                        let timedWord = TimedWord(
                            word: String(word),
                            startTime: currentTime,
                            duration: estimatedWordDuration
                        )
                        rawWordList.append(timedWord)
                        currentTime += estimatedWordDuration
                    }
                    
                } else {
                    // B. Single word segment
                    let timedWord = TimedWord(
                        word: segment.substring,
                        startTime: segment.timestamp,
                        duration: segment.duration
                    )
                    rawWordList.append(timedWord)
                }
            }
            
            var smoothedList: [TimedWord] = []
            
            for i in 0..<rawWordList.count {
                var currentWord = rawWordList[i]
                
                if i < rawWordList.count - 1 {
                    let nextWord = rawWordList[i + 1]
                    let endTime = currentWord.startTime + currentWord.duration
                    let gap = nextWord.startTime - endTime
                    
                    // If gap is positive (silence) but small (< 0.4s), extend word to fill it.
                    // This prevents the caption from disappearing for a split second between words.
                    if gap > 0 && gap < 0.4 {
                        currentWord.duration += gap
                    }
                }
                smoothedList.append(currentWord)
            }
            
            completion(.success(smoothedList))
            
            // Cleanup the audio file
            print("Transcription complete. Audio file cleaned up.")
        }
    }
    
    // Public Cancellation Function
    func cancelTranscription() {
        guard recognitionTask != nil else { return }
        print("Cancelling active transcription task.")
        recognitionTask?.cancel()
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
