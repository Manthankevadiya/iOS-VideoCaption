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
    
    func updateDrag(currentCenter: CGPoint, videoRect: CGRect) -> CGPoint {
        var snappedCenter = currentCenter
        let midX = videoRect.midX
        let midY = videoRect.midY
        
        // --- CENTER LINES SNAPPING ---
        let diffX = currentCenter.x - midX
        let effectiveThresholdX = isSnappedX ? snapThreshold + 5.0 : snapThreshold
        if abs(diffX) < effectiveThresholdX {
            snappedCenter.x = midX
            showVerticalGuide(at: midX, rect: videoRect)
            if !isSnappedX {
                triggerHaptic()
                isSnappedX = true
            }
        } else {
            isSnappedX = false
            hideVerticalGuide()
        }
        
        let diffY = currentCenter.y - midY
        let effectiveThresholdY = isSnappedY ? snapThreshold + 5.0 : snapThreshold
        if abs(diffY) < effectiveThresholdY {
            snappedCenter.y = midY
            showHorizontalGuide(at: midY, rect: videoRect)
            if !isSnappedY {
                triggerHaptic()
                isSnappedY = true
            }
        } else {
            isSnappedY = false
            hideHorizontalGuide()
        }
        
        // --- SAFE AREA LINES ---
        // Show safe lines if currentCenter is within safeAreaThreshold of video edges
        
        // Top
        if abs(currentCenter.y - videoRect.minY) < safeAreaThreshold {
            safeTopLine.frame = CGRect(x: videoRect.minX,
                                       y: videoRect.minY - 1,
                                       width: videoRect.width,
                                       height: 2)
            safeTopLine.isHidden = false
        } else {
            safeTopLine.isHidden = true
        }
        
        // Bottom
        if abs(currentCenter.y - videoRect.maxY) < safeAreaThreshold {
            safeBottomLine.frame = CGRect(x: videoRect.minX,
                                          y: videoRect.maxY - 1,
                                          width: videoRect.width,
                                          height: 2)
            safeBottomLine.isHidden = false
        } else {
            safeBottomLine.isHidden = true
        }
        
        // Left
        if abs(currentCenter.x - videoRect.minX) < safeAreaThreshold {
            safeLeftLine.frame = CGRect(x: videoRect.minX - 1,
                                        y: videoRect.minY,
                                        width: 2,
                                        height: videoRect.height)
            safeLeftLine.isHidden = false
        } else {
            safeLeftLine.isHidden = true
        }
        
        // Right
        if abs(currentCenter.x - videoRect.maxX) < safeAreaThreshold {
            safeRightLine.frame = CGRect(x: videoRect.maxX - 1,
                                         y: videoRect.minY,
                                         width: 2,
                                         height: videoRect.height)
            safeRightLine.isHidden = false
        } else {
            safeRightLine.isHidden = true
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
