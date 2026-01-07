//
//  LanguageTvCell.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 03/11/25.
//

import UIKit

class LanguageTvCell: UITableViewCell {

    @IBOutlet weak var lbl_lang: UILabel!
    @IBOutlet weak var img_tick: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
