//
//  PickVideoPopUp.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 31/10/25.
//

import UIKit
import AVFoundation
import Photos

class PickVideoPopUp: UIViewController {
    
    @IBOutlet weak var view_popUpBg: UIView!
    
    @IBOutlet weak var btn_cancel: UIButton!
    @IBOutlet weak var btn_select: UIButton!
    
    @IBOutlet weak var img_chooseVideoRadio: UIImageView!
    @IBOutlet weak var img_recordVideoRadio: UIImageView!
    
    var wantToRecord = false
    
    var clickCancel: (()->())?
    var clickSelect: ((_ wantToRecord: Bool)->())?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setUpUI()
    }
    
    func setUpUI() {
        self.view_popUpBg.setCorder(radius: 12)
        self.btn_cancel.setCorder(radius: 12)
        self.btn_select.setCorder(radius: 12)
    }
    
    @IBAction func clickOnChooseVideo(_ sender: Any) {
        self.wantToRecord = false
        
        self.img_chooseVideoRadio.image = .icRadioFill
        self.img_recordVideoRadio.image = .icRadio
    }
    
    @IBAction func clickOnRecordVideo(_ sender: Any) {
        self.wantToRecord = true
        
        self.img_recordVideoRadio.image = .icRadioFill
        self.img_chooseVideoRadio.image = .icRadio
    }
    
    @IBAction func clickOnCancel(_ sender: Any) {
        self.dismiss(animated: true) {
            self.clickCancel?()
        }
    }
    
    @IBAction func clickOnSelect(_ sender: Any) {
        if self.wantToRecord {
            self.checkCameraPermissionAndRecord { granted in
                if granted {
                    self.dismiss(animated: true) {
                        self.clickSelect?(true)
                    }
                } else {
                    self.showAleartPopUp(title: "Camera Access Needed",
                                         message: "Enable camera access in Settings to record a video.")
                }
            }
        } else {
            self.checkPhotoPermissionAndPick { granted in
                if granted {
                    self.dismiss(animated: true) {
                        self.clickSelect?(false)
                    }
                } else {
                    self.showAleartPopUp(title: "Photos Access Needed",
                                      message: "Enable photo access in Settings to choose a video.")
                }
            }
        }
    }
    
}

extension PickVideoPopUp {
    
    func checkCameraPermissionAndRecord(completion: ((Bool)->())? = nil) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            completion?(true)
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        completion?(true)
                    } else {
                        completion?(false)
                    }
                }
            }
            
        case .denied, .restricted:
            completion?(false)
        @unknown default:
            break
        }
    }
    
    func checkPhotoPermissionAndPick(completion: ((Bool)->())? = nil) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized, .limited:
            completion?(true)

        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        completion?(true)
                    } else {
                        completion?(false)
                    }
                }
            }

        case .denied, .restricted:
            completion?(false)
        @unknown default:
            break
        }
    }
    
}
