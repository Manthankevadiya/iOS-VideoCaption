//
//  VideoAnalyzerView.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 10/11/25.
//


import UIKit
import AVFoundation

class VideoAnalyzerView: UIView {
    private let thumbnailImageView = UIImageView()
    private let scanningLineView = UIView()
    
    // --- Size and Rotation Constants ---
    private let thumbnailPaddingVertical: CGFloat = 60
    private let thumbnailPaddingHorizontal: CGFloat = 15
    
    private let rotationAngle: CGFloat = CGFloat.pi / 36 // 5 degrees
    private let bottomSpace: CGFloat = 20
    private let lineOvershoot: CGFloat = 10
    private let scanningLineWidth: CGFloat = 6
    
    private var isVertical: Bool = true
    
    // --- Dynamic Constraint Properties ---
    private var heightVerticalConstraint: NSLayoutConstraint?
    private var heightHorizontalConstraint: NSLayoutConstraint?
    private var widthConstraintsVertical: [NSLayoutConstraint]?
    private var widthConstraintsHorizontal: [NSLayoutConstraint]?
    
    // --- Initialization ---
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        addAppLifecycleObservers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        addAppLifecycleObservers()
    }
    
    deinit {
        removeAppLifecycleObservers()
    }
    
    // --- Setup ---
    private func setupViews() {
        // 1. Setup Thumbnail ImageView
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.layer.cornerRadius = 12
        thumbnailImageView.backgroundColor = .darkGray
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(thumbnailImageView)
        
        // 2. Setup Scanning Line View
        scanningLineView.backgroundColor = UIColor.white
        scanningLineView.layer.shadowColor = UIColor(red: 0.1, green: 0.7, blue: 1.0, alpha: 1.0).cgColor
        scanningLineView.layer.shadowOpacity = 1
        scanningLineView.layer.shadowRadius = 10
        scanningLineView.layer.shadowOffset = .zero
        scanningLineView.layer.masksToBounds = false
        scanningLineView.isHidden = true
        scanningLineView.layer.cornerRadius = scanningLineWidth / 2.0
        
        scanningLineView.translatesAutoresizingMaskIntoConstraints = true
        self.addSubview(scanningLineView)
        
        // 3. Apply Base Constraints (Center and Bottom)
        NSLayoutConstraint.activate([
            thumbnailImageView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -bottomSpace),
        ])
        
        // 4. Define Dynamic Constraints (Width)
        widthConstraintsVertical = [
            thumbnailImageView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: thumbnailPaddingVertical),
            thumbnailImageView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -thumbnailPaddingVertical),
        ]
        widthConstraintsHorizontal = [
            thumbnailImageView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: thumbnailPaddingHorizontal),
            thumbnailImageView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -thumbnailPaddingHorizontal),
        ]
        
        // 5. Define Dynamic Constraints (Height)
        heightVerticalConstraint = thumbnailImageView.heightAnchor.constraint(equalTo: self.heightAnchor, multiplier: 0.55)
        heightHorizontalConstraint = thumbnailImageView.heightAnchor.constraint(equalTo: self.heightAnchor, multiplier: 0.35)
    }
    
    // --- Layout and Life Cycle ---
    override func layoutSubviews() {
        super.layoutSubviews()
        applyRotationTransform()
        setInitialScanningLinePosition()
    }
    
    // MARK: - Core Rotation Logic (Fixed rotation)
    private func applyRotationTransform() {
        var transform = CGAffineTransform.identity
        transform = transform.rotated(by: -rotationAngle)
        thumbnailImageView.transform = transform
    }
    
    // MARK: - App Lifecycle Management (RESTART FIX)
    private func addAppLifecycleObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    private func removeAppLifecycleObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleAppDidEnterBackground() {
        print("⏸️ App did enter background. Removing/Stopping animation.")
        // REMOVE: This prevents the layer speed from being stuck at 0.0
        scanningLineView.layer.removeAllAnimations()
    }
    
    @objc private func handleAppWillEnterForeground() {
        print("🎬 App will enter foreground. Restarting animation if needed.")
        // Call startScanningAnimation to fully re-add the animation object
        if !scanningLineView.isHidden {
            startScanningAnimation()
        }
    }
    
    // NOTE: The previous pauseLayer and resumeLayer methods have been removed
    // to eliminate the source of the speed=0.0 issue.
    
    // MARK: - Scanning Line Logic
    private func setInitialScanningLinePosition() {
        let lineThickness = scanningLineWidth
        
        scanningLineView.transform = .identity
        
        let thumbnailFrame = thumbnailImageView.frame
        
        if isVertical {
            let lineW = thumbnailFrame.width + 2 * lineOvershoot
            let lineX = thumbnailFrame.minX - lineOvershoot
            
            scanningLineView.frame = CGRect(
                x: lineX,
                y: thumbnailFrame.maxY - lineThickness,
                width: lineW,
                height: lineThickness
            )
        } else {
            let lineH = thumbnailFrame.height + 2 * lineOvershoot
            let lineY = thumbnailFrame.minY - lineOvershoot
            
            scanningLineView.frame = CGRect(
                x: thumbnailFrame.minX,
                y: lineY,
                width: lineThickness,
                height: lineH
            )
        }
    }
    
    func startScanningAnimation() {
        print("✨ Starting scanning animation (isVertical: \(isVertical))")
        let lineFrame = scanningLineView.frame
        let thumbnailFrame = thumbnailImageView.frame

        // Ensure the line is in the correct initial position before adding the animation
        setInitialScanningLinePosition()
        
        scanningLineView.layer.removeAllAnimations()
        scanningLineView.isHidden = false
        
        let animationKeyPath: String
        let fromValue: CGFloat
        let toValue: CGFloat
        let duration: CFTimeInterval = 2.0
        
        if isVertical {
            animationKeyPath = "position.y"
            fromValue = thumbnailFrame.maxY - (lineFrame.height / 2)
            toValue = thumbnailFrame.minY + (lineFrame.height / 2)
        } else {
            animationKeyPath = "position.x"
            fromValue = thumbnailFrame.minX + (lineFrame.width / 2)
            toValue = thumbnailFrame.maxX - (lineFrame.width / 2)
        }
        
        let animation = CABasicAnimation(keyPath: animationKeyPath)
        animation.fromValue = fromValue
        animation.toValue = toValue
        animation.duration = duration
        animation.repeatCount = .infinity
        animation.autoreverses = true
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        scanningLineView.layer.add(animation, forKey: "scanningAnimation")
    }
    
    // MARK: - Dynamic Constraint Activation
    func setVideoThumbnail(image: UIImage) {
        let newIsVertical = image.size.height > image.size.width
        
        if newIsVertical != self.isVertical || (heightVerticalConstraint?.isActive == false && heightHorizontalConstraint?.isActive == false) {
            
            NSLayoutConstraint.deactivate(widthConstraintsVertical ?? [])
            NSLayoutConstraint.deactivate(widthConstraintsHorizontal ?? [])
            heightVerticalConstraint?.isActive = false
            heightHorizontalConstraint?.isActive = false

            if newIsVertical {
                NSLayoutConstraint.activate(widthConstraintsVertical ?? [])
                heightVerticalConstraint?.isActive = true
            } else {
                NSLayoutConstraint.activate(widthConstraintsHorizontal ?? [])
                heightHorizontalConstraint?.isActive = true
            }
            
            self.isVertical = newIsVertical
        }
        
        thumbnailImageView.image = image
        
        self.setNeedsLayout()
        self.layoutIfNeeded()
        
        startScanningAnimation()
    }
    
    func stopScanningAnimation() {
        print("🛑 Stopping scanning animation.")
        scanningLineView.layer.removeAllAnimations()
        scanningLineView.isHidden = true
    }
}

