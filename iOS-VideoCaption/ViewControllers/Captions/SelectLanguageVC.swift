//
//  SelectLanguageVC.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 03/11/25.
//

import UIKit
import AVKit
import Speech

class SelectLanguageVC: UIViewController {
    
    @IBOutlet weak var view_player: UIView!
    @IBOutlet weak var view_selectLang: UIView!
    @IBOutlet weak var lbl_language: UILabel!
    
    @IBOutlet weak var btn_next: UIButton!
    
    var project: CaptionEntity!
    var selectedLanguage : (id: String, name: String)?
    private var playerVC: AVPlayerViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setUpUI()
        self.setUpPlayer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.playerVC?.player?.pause()
    }
    
    func setUpUI() {
        self.view_player.setCorder(radius: 12)
        self.view_selectLang.setCorder(radius: 12)
        self.btn_next.setCorder(radius: 12)
    }
    
    func setUpPlayer() {
        guard let videoURL = self.project.currentAbsoluteVideoURL else { return }
        
        print(videoURL, "m̐")
        
        let player = AVPlayer(url: videoURL)
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        playerVC.view.frame = self.view_player.bounds
        playerVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        playerVC.showsPlaybackControls = true
        playerVC.videoGravity = .resizeAspect
        
        // Embed playerVC inside view_player
        addChild(playerVC)
        self.view_player.addSubview(playerVC.view)
        playerVC.didMove(toParent: self)
        
        self.playerVC = playerVC
        player.play()
    }
    
    private func requestSpeechPermissionIfNeeded(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    completion(true)
                    
                case .denied, .restricted, .notDetermined:
                    self.showAleartPopUp(title: "Speech Permission Needed", message: "This allows the app to transcribe audio from your videos for synchronized text animations.")
                    completion(false)
                    
                @unknown default:
                    self.showAleartPopUp(title: "Speech Permission Needed", message: "This allows the app to transcribe audio from your videos for synchronized text animations.")
                    completion(false)
                }
            }
        }
    }
    
    @IBAction func clickOnBack(_ sender: Any) {
        self.popVC()
    }
    
    @IBAction func clickOnSelectLang(_ sender: Any) {
        let vc = LanguageBottomSheet.instantiate()
        
        let currentLangCode = self.selectedLanguage?.id ?? self.project.selectedLanguage ?? "en-US"
        vc.selectedLangCode = currentLangCode
        
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.preferredCornerRadius = 20
            sheet.largestUndimmedDetentIdentifier = .medium
            
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.prefersEdgeAttachedInCompactHeight = true
        }
        
        vc.clickContinue = { langData in
            self.selectedLanguage = langData
            self.lbl_language.text = langData.name
            
            if langData.id != self.project.selectedLanguage {
                self.project.selectedLanguage = langData.id
                CoreDataManager.shared.saveContext()
            }
        }
        
        self.present(vc, animated: true)
    }
    
    @IBAction func clickOnNext(_ sender: Any) {
        self.requestSpeechPermissionIfNeeded { granted in
            if granted {
                let vc = GeneratingCaptionVC.instantiate()
                vc.project = self.project
                self.pushVC(vc: vc, animation: true)
            }
        }
    }
    
}
