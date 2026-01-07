//
//  GeneratingCaptionVC.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 10/11/25.
//

import UIKit

class GeneratingCaptionVC: UIViewController {

    @IBOutlet weak var view_videoAnimation: UIView!
    @IBOutlet weak var btn_cancel: UIButton!
    
    private let coreDataManager = CoreDataManager.shared
    private var captionManager : CaptionManager?
    
    private let analyzerView = VideoAnalyzerView()
    private let imageGenerator = VideoImageGenerator()
    
    var project: CaptionEntity!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setUpUI()
        self.setupAnalyzerView()
        self.startVideoProcessingAnimation()
        self.startTranscriptionProcess()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.analyzerView.stopScanningAnimation()
        self.captionManager?.cancelTranscription()
    }
    
    func setUpUI() {
        self.btn_cancel.setCorder(radius: 12)
    }
    
    private func setupAnalyzerView() {
        // Add the custom view to the IBOutlet container
        self.view_videoAnimation.addSubview(self.analyzerView)
        
        // Use Auto Layout to make the analyzer view fit perfectly inside the container view
        self.analyzerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.analyzerView.topAnchor.constraint(equalTo: self.view_videoAnimation.topAnchor),
            self.analyzerView.bottomAnchor.constraint(equalTo: self.view_videoAnimation.bottomAnchor),
            self.analyzerView.leadingAnchor.constraint(equalTo: self.view_videoAnimation.leadingAnchor),
            self.analyzerView.trailingAnchor.constraint(equalTo: self.view_videoAnimation.trailingAnchor)
        ])
    }
    
    private func startVideoProcessingAnimation() {
        guard let storedFileName = self.project.currentAbsoluteVideoURL else {
            print("Error: Core Data videoLink is empty or nil.")
            return
        }
        print("Loading VC: Reconstructed URL for initial thumbnail: \(storedFileName.absoluteString)")
        
        let url = storedFileName
        
        Task {
            
            let (thumbnail, timelineImages) = await (
                self.imageGenerator.generateThumbnail(from: url),
                self.imageGenerator.generateTimelineImages(from: url)
            )
            
            if let thumbnail = thumbnail {
                DispatchQueue.main.async {
                    self.analyzerView.setVideoThumbnail(image: thumbnail)
                }
                
                let timelineImages = timelineImages
                if !timelineImages.isEmpty {
                    self.coreDataManager.saveVideoImages(
                        to: self.project,
                        thumbnail: thumbnail,
                        timelineImages: timelineImages
                    )
                }
            } else {
                DispatchQueue.main.async {
                    print("Error: Could not load video thumbnail.")
                    // Set a simple colored square placeholder if needed
                    let defaultImage = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in
                        UIColor.darkGray.setFill()
                        UIRectFill(CGRect(x: 0, y: 0, width: 1, height: 1))
                    }
                    self.analyzerView.setVideoThumbnail(image: defaultImage)
                }
            }
        }
    }
    
    // MARK: - Transcription & Core Data
    private func startTranscriptionProcess() {
        
        // 1. Get the necessary data from the project
        guard let videoLink = self.project.currentAbsoluteVideoURL else {
            self.handleTranscriptionError(error: NSError(domain: "AppError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Video link is invalid."]))
            return
        }
        
        let tempAudioURL = videoLink
        
        let languageCode = self.project.selectedLanguage ?? "en-US"
        print("🗣️ Initializing Transcriber with Language: \(languageCode)")
        
        // Initialize Manager with this language
        self.captionManager = CaptionManager(languageCode: languageCode)
        
        // 2. Start Transcription
        self.captionManager?.transcribeAudio(url: tempAudioURL) { [weak self] result in
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.analyzerView.stopScanningAnimation()
                
                switch result {
                case .success(let timedWords):
                    
                    // a. Reconstruct the full text
                    let fullText = timedWords.map { $0.word }.joined(separator: " ")
                    
                    // b. Convert TimedWord structs to Core Data required tuple format
                    let wordDataTuples: [(text: String, startTime: Double, endTime: Double)] = timedWords.map { word in
                        return (text: word.word, startTime: word.startTime, endTime: word.startTime + word.duration)
                    }
                    
                    // 3. Save the results to Core Data
                    self.coreDataManager.saveTranscription(
                        to: self.project,
                        language: self.project.selectedLanguage ?? "en-US",
                        fullText: fullText,
                        wordData: wordDataTuples
                    )
                    
                    print("💾 Data saved successfully for project: \(self.project.videoName ?? "Unknown")")
                    self.printFullProjectDetails()
                    self.handleTranscriptionCompletion()
                    
                case .failure(let error):
                    let nsError = error as NSError
                    if nsError.code == 203 {
                        self.handleTranscriptionCancellation()
                    } else {
                        self.handleTranscriptionError(error: nsError)
                    }
                }
            }
        }
    }
    
    private func printFullProjectDetails() {
        print("\n=======================================================")
        print("✅ PROJECT TRANSCRIPTION SUCCESSFUL & SAVED")
        print("=======================================================")
        
        // 1. Parent Project Details
        print("🎥 **Project Name:** \(project.videoName ?? "N/A") (\(project.videoID ?? UUID()))")
        print("🔗 **Video Link:** \(project.videoLink ?? "N/A")")
        print("🗣️ **Language:** \(project.selectedLanguage ?? "N/A")")
        print("⏱️ **Total Duration:** \(String(format: "%.2f", project.totalDuration)) seconds")
        print("📝 **Full Transcribed Text:**")
        print("   '\(project.fullCaptionText ?? "N/A")'")
        print("-------------------------------------------------------")
        
        // 2. Style Details (A few examples)
        print("🎨 **Style Defaults:**")
        print("   Font: \(project.captionFontName ?? "N/A"), Size: \(project.captionFontSize)")
        print("   Position: (\(String(format: "%.2f", project.captionPositionX)), \(String(format: "%.2f", project.captionPositionY)))")
        print("   Animation: \(project.captionAnimationType)")
        print("-------------------------------------------------------")
        
        // 3. Timed Word Segments
        print("📖 **Timed Word Segments (TranscribedEntity):**")
        
        let transcribedWords = coreDataManager.fetchTranscription(for: project)
        
        if transcribedWords.isEmpty {
            print("(No timed words found, check `fetchTranscription` logic.)")
        } else {
            for (index, wordEntity) in transcribedWords.enumerated() {
                let startTime = String(format: "%.3f", wordEntity.startTime)
                let endTime = String(format: "%.3f", wordEntity.endTime)
                print("[\(index)] \(wordEntity.text ?? "") [\(startTime)s - \(endTime)s]")
            }
        }
        print("=======================================================\n")
    }
    
    private func handleTranscriptionCompletion() {
        // Logic after successful transcription and saving
        print("Flow: Transcription complete. Moving to editor.")
        let vc = CaptionVC.instantiate()
        vc.project = self.project
        self.pushVC(vc: vc, animation: true)
    }
    
    private func handleTranscriptionCancellation() {
        // Logic after user manually cancels the process
        print("Flow: User cancelled transcription. Resetting state.")
        // You may want to delete the project here if it's incomplete:
        // self.coreDataManager.deleteProject(self.project)
//        self.popVC()
    }
    
    private func handleTranscriptionError(error: NSError) {
        // Logic after a system error
        print("Flow: Transcription Error \(error.code): \(error.localizedDescription)")
        // Show an error alert to the user before dismissing
        let alert = UIAlertController(title: "Transcription Failed", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.popVC()
        })
        self.present(alert, animated: true)
    }
    
    @IBAction func clickOnCancel(_ sender: Any) {
        self.popVC()
    }
    
}
