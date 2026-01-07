//
//  ColorCvCell.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 25/11/25.
//

import UIKit

class ColorCvCell: UICollectionViewCell {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.layer.cornerRadius = 8
        self.clipsToBounds = true
    }
    
    func configure(with color: String, isSelected: Bool) {
        self.contentView.backgroundColor = UIColor(hex: color)
        
        if isSelected {
            self.layer.borderColor = UIColor.color8137FF.cgColor
            self.layer.borderWidth = 2
        } else {
            self.layer.borderWidth = 0
        }
        
        self.setSelectedState(isSelected)
    }
    
    func setSelectedState(_ isSelected: Bool) {
        UIView.animate(withDuration: 0.25,
                       delay: 0,
                       usingSpringWithDamping: 0.7,
                       initialSpringVelocity: 0.5,
                       options: .curveEaseInOut,
                       animations: {
            self.transform = isSelected
                ? CGAffineTransform(translationX: 0, y: -12)
                : .identity
        })
    }
    
}
