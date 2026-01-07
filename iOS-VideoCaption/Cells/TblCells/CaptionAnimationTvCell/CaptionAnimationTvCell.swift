//
//  CaptionAnimationTvCell.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 24/11/25.
//

import UIKit

class CaptionAnimationTvCell: UITableViewCell {
    
    @IBOutlet weak var view_caption: UIView!
    @IBOutlet weak var lbl_caption: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.selectionStyle = .none
        
        self.lbl_caption.textAlignment = .center
        self.lbl_caption.numberOfLines = 1
        self.lbl_caption.lineBreakMode = .byClipping
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        //
    }
    
}
