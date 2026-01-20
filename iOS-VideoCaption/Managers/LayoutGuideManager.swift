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
    
    public let leftVerticalGuideLine: UIView = {
        let v = UIView()
        v.backgroundColor = .yellow
        v.isHidden = true
        return v
    }()
    
    public let verticalGuideLine: UIView = {
        let v = UIView()
        v.backgroundColor = .yellow
        v.isHidden = true
        return v
    }()
    
    public let rightVerticalGuideLine: UIView = {
        let v = UIView()
        v.backgroundColor = .yellow
        v.isHidden = true
        return v
    }()
    
    public let topHorizontalGuideLine: UIView = {
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
    
    public let bottomHorizontalGuideLine: UIView = {
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
        container.addSubview(leftVerticalGuideLine)
        container.addSubview(rightVerticalGuideLine)
        
        container.addSubview(horizontalGuideLine)
        container.addSubview(topHorizontalGuideLine)
        container.addSubview(bottomHorizontalGuideLine)
        
        container.addSubview(safeTopLine)
        container.addSubview(safeBottomLine)
        container.addSubview(safeLeftLine)
        container.addSubview(safeRightLine)
    }
    
    func beginDrag(videoRect: CGRect) {
        guard let container = containerView else { return }
        
        container.bringSubviewToFront(verticalGuideLine)
        container.bringSubviewToFront(leftVerticalGuideLine)
        container.bringSubviewToFront(rightVerticalGuideLine)
        
        container.bringSubviewToFront(horizontalGuideLine)
        container.bringSubviewToFront(topHorizontalGuideLine)
        container.bringSubviewToFront(bottomHorizontalGuideLine)
        
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

        let diffX = currentCenter.x - midX
        let diffY = currentCenter.y - midY

        // -----------------------
        // VERTICAL CENTER LOGIC
        // -----------------------

        if abs(diffX) < visualGuideThreshold {
            showVerticalGuide(at: midX, rect: videoRect)
            showSecondaryVerticalGuides(centerX: midX, rect: videoRect)

            let effectiveThreshold = isSnappedX ? snapThreshold + 5 : snapThreshold
            if abs(diffX) < effectiveThreshold {
                snappedCenter.x = midX
                if !isSnappedX {
                    triggerHaptic()
                    isSnappedX = true
                }
            } else {
                isSnappedX = false
            }
        } else {
            hideVerticalGuide()
            leftVerticalGuideLine.isHidden = true
            rightVerticalGuideLine.isHidden = true
            isSnappedX = false
        }

        // -----------------------
        // HORIZONTAL CENTER LOGIC
        // -----------------------

        if abs(diffY) < visualGuideThreshold {
            showHorizontalGuide(at: midY, rect: videoRect)
            showSecondaryHorizontalGuides(centerY: midY, rect: videoRect)

            let effectiveThreshold = isSnappedY ? snapThreshold + 5 : snapThreshold
            if abs(diffY) < effectiveThreshold {
                snappedCenter.y = midY
                if !isSnappedY {
                    triggerHaptic()
                    isSnappedY = true
                }
            } else {
                isSnappedY = false
            }
        } else {
            hideHorizontalGuide()
            topHorizontalGuideLine.isHidden = true
            bottomHorizontalGuideLine.isHidden = true
            isSnappedY = false
        }

        // -----------------------
        // SAFE AREA GUIDES
        // -----------------------

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
            safeTopLine.frame = CGRect(x: videoRect.minX, y: videoRect.minY - 1,
                                       width: videoRect.width, height: 2)
        }

        if !safeBottomLine.isHidden {
            safeBottomLine.frame = CGRect(x: videoRect.minX, y: videoRect.maxY - 1,
                                          width: videoRect.width, height: 2)
        }

        if !safeLeftLine.isHidden {
            safeLeftLine.frame = CGRect(x: videoRect.minX - 1, y: videoRect.minY,
                                        width: 2, height: videoRect.height)
        }

        if !safeRightLine.isHidden {
            safeRightLine.frame = CGRect(x: videoRect.maxX - 1, y: videoRect.minY,
                                         width: 2, height: videoRect.height)
        }

        return snappedCenter
    }
    
    func endDrag() {
        verticalGuideLine.isHidden = true
        leftVerticalGuideLine.isHidden = true
        rightVerticalGuideLine.isHidden = true
        
        horizontalGuideLine.isHidden = true
        topHorizontalGuideLine.isHidden = true
        bottomHorizontalGuideLine.isHidden = true
        
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
    
    private func showSecondaryVerticalGuides(centerX: CGFloat, rect: CGRect) {
        let spacing = rect.width / 4

        leftVerticalGuideLine.frame = CGRect(
            x: centerX - spacing - 1,
            y: rect.minY,
            width: 2,
            height: rect.height
        )

        rightVerticalGuideLine.frame = CGRect(
            x: centerX + spacing - 1,
            y: rect.minY,
            width: 2,
            height: rect.height
        )

        leftVerticalGuideLine.isHidden = false
        rightVerticalGuideLine.isHidden = false
    }

    private func showSecondaryHorizontalGuides(centerY: CGFloat, rect: CGRect) {
        let spacing = rect.height / 4

        topHorizontalGuideLine.frame = CGRect(
            x: rect.minX,
            y: centerY - spacing - 1,
            width: rect.width,
            height: 2
        )

        bottomHorizontalGuideLine.frame = CGRect(
            x: rect.minX,
            y: centerY + spacing - 1,
            width: rect.width,
            height: 2
        )

        topHorizontalGuideLine.isHidden = false
        bottomHorizontalGuideLine.isHidden = false
    }

    
}
