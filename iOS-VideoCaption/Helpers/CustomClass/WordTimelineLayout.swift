//
//  WordTimelineLayout.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 05/01/26.
//

import UIKit

final class WordTimelineLayout: UICollectionViewLayout {
    var segments: [WordSegment] = []
    var pointsPerSecond: CGFloat = 60
    var leadingOffset: CGFloat = 50
    var rowHeight: CGFloat = 35
    
    private var cache: [UICollectionViewLayoutAttributes] = []
    private var contentWidth: CGFloat = 0
    
    override func prepare() {
        guard let cv = collectionView else { return }
        cache.removeAll()
        
        var maxX: CGFloat = 0
        for (i, seg) in segments.enumerated() {
            let attr = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: i, section: 0))
            
            let x = leadingOffset + CGFloat(seg.start) * pointsPerSecond
            let w = max(20, (CGFloat(seg.duration) * pointsPerSecond) - 1.0)
            
            attr.frame = CGRect(x: x, y: 0, width: w, height: rowHeight)
            cache.append(attr)
            maxX = max(maxX, x + w)
        }
        
        contentWidth = max(maxX, cv.bounds.width)
    }
    
    override var collectionViewContentSize: CGSize {
        CGSize(width: contentWidth, height: rowHeight)
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        cache.filter { $0.frame.intersects(rect) }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        indexPath.item < cache.count ? cache[indexPath.item] : nil
    }
}
