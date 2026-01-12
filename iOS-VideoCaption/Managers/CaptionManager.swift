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
    
    init?(languageCode: String) {
        let locale = Locale(identifier: languageCode)
        
        // Check if this specific locale is supported
        guard SFSpeechRecognizer.supportedLocales().contains(locale) else {
            print("Locale \(languageCode) is not supported by Speech Framework")
            return nil
        }
        
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
        
        // 1. Ensure the recognizer exists and is available
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            let error = NSError(domain: "CaptionManagerError", code: 1,
                                userInfo: [NSLocalizedDescriptionKey: "Speech recognizer is not available for the selected language or device."])
            completion(.failure(error))
            return
        }
        
        // 2. Setup Audio Session
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
        request.taskHint = .dictation
        
        // --- THE FIX ---
        // Check if on-device recognition is actually supported for THIS specific language.
        // If it's not downloaded or supported, we set this to 'false' so it can use Apple's servers.
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        } else {
            print("⚠️ On-device assets not found for \(recognizer.locale.identifier). Using server-based recognition.")
            request.requiresOnDeviceRecognition = false
        }
        
        if #available(iOS 16, *) {
            request.addsPunctuation = true
        }
        
        print("Starting transcription [Locale: \(recognizer.locale.identifier)]")
        
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] (result, error) in
            
            defer {
                if result?.isFinal == true || error != nil {
                    self?.recognitionTask = nil
                    try? AVAudioSession.sharedInstance().setActive(false)
                }
            }
            
            guard let self = self else { return }
            
            if let error = error {
                let nsError = error as NSError
                // Error 203 is user cancellation, Error 1101/1110 usually relate to asset/internet issues
                if nsError.code == 203 {
                    print("Transcription cancelled.")
                } else {
                    completion(.failure(error))
                }
                return
            }
            
            guard let result = result, result.isFinal else { return }
            
            // --- DATA EXTRACTION ---
            let segments = result.bestTranscription.segments
            var rawWordList: [TimedWord] = []
            
            for segment in segments {
                // Handle multi-word segments
                if segment.substring.contains(" ") {
                    let segmentWords = segment.substring.split(separator: " ")
                    let estimatedWordDuration = segment.duration / max(Double(segmentWords.count), 1.0)
                    var currentTime = segment.timestamp
                    
                    for word in segmentWords {
                        rawWordList.append(TimedWord(
                            word: String(word),
                            startTime: currentTime,
                            duration: estimatedWordDuration
                        ))
                        currentTime += estimatedWordDuration
                    }
                } else {
                    rawWordList.append(TimedWord(
                        word: segment.substring,
                        startTime: segment.timestamp,
                        duration: segment.duration
                    ))
                }
            }
            
            // --- SMOOTHING ---
            var smoothedList: [TimedWord] = []
            for i in 0..<rawWordList.count {
                var currentWord = rawWordList[i]
                if i < rawWordList.count - 1 {
                    let nextWord = rawWordList[i + 1]
                    let gap = nextWord.startTime - (currentWord.startTime + currentWord.duration)
                    if gap > 0 && gap < 0.4 {
                        currentWord.duration += gap
                    }
                }
                smoothedList.append(currentWord)
            }
            
            completion(.success(smoothedList))
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
