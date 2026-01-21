//
//  LayoutGuideManager.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 11/12/25.
//

import UIKit

class LayoutGuideManager {
    
    private weak var containerView: UIView?
    
    // Made public (read-only) so VC can bringToFront if needed
    public let verticalGuideLine: UIView = {
        let v = UIView()
        v.backgroundColor = .yellow
        v.isHidden = true
        return v
    }()
    
    public let horizontalGuideLine: UIView = {
        let v = UIView()
        v.backgroundColor = .yellow
        v.isHidden = true
        return v
    }()
    
    // Safe Area Border Lines: top, bottom, left, right
    public let safeTopLine: UIView = {
        let v = UIView()
        v.backgroundColor = .green
        v.isHidden = true
        return v
    }()
    
    public let safeBottomLine: UIView = {
        let v = UIView()
        v.backgroundColor = .green
        v.isHidden = true
        return v
    }()
    
    public let safeLeftLine: UIView = {
        let v = UIView()
        v.backgroundColor = .green
        v.isHidden = true
        return v
    }()
    
    public let safeRightLine: UIView = {
        let v = UIView()
        v.backgroundColor = .green
        v.isHidden = true
        return v
    }()
    
    var snapThreshold: CGFloat = 6 // Snap threshold for center lines
    var safeAreaThreshold: CGFloat = 15 // Threshold distance to safe edges to show lines
    private let visualGuideThreshold: CGFloat = 40
    
    private let feedbackGenerator = UISelectionFeedbackGenerator()
    private var isSnappedX = false
    private var isSnappedY = false
    
    init(container: UIView) {
        self.containerView = container
        setupGuides()
    }
    
    private func setupGuides() {
        guard let container = containerView else { return }
        
        container.addSubview(verticalGuideLine)
        container.addSubview(horizontalGuideLine)
        
        container.addSubview(safeTopLine)
        container.addSubview(safeBottomLine)
        container.addSubview(safeLeftLine)
        container.addSubview(safeRightLine)
    }
    
    func beginDrag(videoRect: CGRect) {
        guard let container = containerView else { return }
        
        container.bringSubviewToFront(verticalGuideLine)
        container.bringSubviewToFront(horizontalGuideLine)
        
        container.bringSubviewToFront(safeTopLine)
        container.bringSubviewToFront(safeBottomLine)
        container.bringSubviewToFront(safeLeftLine)
        container.bringSubviewToFront(safeRightLine)
        
        feedbackGenerator.prepare()
        isSnappedX = false
        isSnappedY = false
    }
    
    func updateDrag(
        currentCenter: CGPoint,
        videoRect: CGRect,
        captionSize: CGSize
    ) -> CGPoint {
        
        var snappedCenter = currentCenter
        
        let midX = videoRect.midX
        let midY = videoRect.midY
        
        // ------------------------------------------------
        // VERTICAL GUIDES (LEFT – CENTER – RIGHT)
        // ------------------------------------------------
        
        let verticalTargets = [
            (x: midX, view: verticalGuideLine),
        ]
        
        var didSnapX = false
        
        for target in verticalTargets {
            let diff = currentCenter.x - target.x
            
            if abs(diff) < visualGuideThreshold {
                target.view.frame = CGRect(
                    x: target.x - 1,
                    y: videoRect.minY,
                    width: 2,
                    height: videoRect.height
                )
                target.view.isHidden = false
                
                let effectiveThreshold = isSnappedX ? snapThreshold + 5 : snapThreshold
                if abs(diff) < effectiveThreshold && !didSnapX {
                    snappedCenter.x = target.x
                    if !isSnappedX {
                        triggerHaptic()
                    }
                    isSnappedX = true
                    didSnapX = true
                }
            } else {
                target.view.isHidden = true
            }
        }
        
        if !didSnapX {
            isSnappedX = false
        }
        
        // ------------------------------------------------
        // HORIZONTAL GUIDES (TOP – CENTER – BOTTOM)
        // ------------------------------------------------
        
        let horizontalTargets = [
            (y: midY, view: horizontalGuideLine),
        ]
        
        var didSnapY = false
        
        for target in horizontalTargets {
            let diff = currentCenter.y - target.y
            
            if abs(diff) < visualGuideThreshold {
                target.view.frame = CGRect(
                    x: videoRect.minX,
                    y: target.y - 1,
                    width: videoRect.width,
                    height: 2
                )
                target.view.isHidden = false
                
                let effectiveThreshold = isSnappedY ? snapThreshold + 5 : snapThreshold
                if abs(diff) < effectiveThreshold && !didSnapY {
                    snappedCenter.y = target.y
                    if !isSnappedY {
                        triggerHaptic()
                    }
                    isSnappedY = true
                    didSnapY = true
                }
            } else {
                target.view.isHidden = true
            }
        }
        
        if !didSnapY {
            isSnappedY = false
        }
        
        // ------------------------------------------------
        // SAFE AREA GUIDES (CAPTION EDGES)
        // ------------------------------------------------
        
        let halfW = captionSize.width / 2
        let halfH = captionSize.height / 2
        
        let minX = snappedCenter.x - halfW
        let maxX = snappedCenter.x + halfW
        let minY = snappedCenter.y - halfH
        let maxY = snappedCenter.y + halfH
        
        safeTopLine.isHidden = abs(minY - videoRect.minY) >= safeAreaThreshold
        safeBottomLine.isHidden = abs(maxY - videoRect.maxY) >= safeAreaThreshold
        safeLeftLine.isHidden = abs(minX - videoRect.minX) >= safeAreaThreshold
        safeRightLine.isHidden = abs(maxX - videoRect.maxX) >= safeAreaThreshold
        
        if !safeTopLine.isHidden {
            safeTopLine.frame = CGRect(x: videoRect.minX, y: videoRect.minY + 12,
                                       width: videoRect.width, height: 2)
        }
        
        if !safeBottomLine.isHidden {
            safeBottomLine.frame = CGRect(x: videoRect.minX, y: videoRect.maxY - 12,
                                          width: videoRect.width, height: 2)
        }
        
        if !safeLeftLine.isHidden {
            safeLeftLine.frame = CGRect(x: videoRect.minX + 12, y: videoRect.minY,
                                        width: 2, height: videoRect.height)
        }
        
        if !safeRightLine.isHidden {
            safeRightLine.frame = CGRect(x: videoRect.maxX - 12, y: videoRect.minY,
                                         width: 2, height: videoRect.height)
        }
        
        return snappedCenter
    }
    
    func endDrag() {
        verticalGuideLine.isHidden = true
        horizontalGuideLine.isHidden = true
        
        safeTopLine.isHidden = true
        safeBottomLine.isHidden = true
        safeLeftLine.isHidden = true
        safeRightLine.isHidden = true
    }
    
    private func showVerticalGuide(at x: CGFloat, rect: CGRect) {
        verticalGuideLine.frame = CGRect(x: x - 1, y: rect.minY, width: 2, height: rect.height)
        verticalGuideLine.isHidden = false
    }
    
    private func hideVerticalGuide() {
        verticalGuideLine.isHidden = true
    }
    
    private func showHorizontalGuide(at y: CGFloat, rect: CGRect) {
        horizontalGuideLine.frame = CGRect(x: rect.minX, y: y - 1, width: rect.width, height: 2)
        horizontalGuideLine.isHidden = false
    }
    
    private func hideHorizontalGuide() {
        horizontalGuideLine.isHidden = true
    }
    
    private func triggerHaptic() {
        feedbackGenerator.selectionChanged()
    }
    
}
