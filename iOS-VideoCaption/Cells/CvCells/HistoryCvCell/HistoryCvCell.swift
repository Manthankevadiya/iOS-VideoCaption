//
//  HistoryCvCell.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 31/10/25.
//

import UIKit

class HistoryCvCell: UICollectionViewCell {

    @IBOutlet weak var view_duration: UIView!
    @IBOutlet weak var lbl_duration: UILabel!
    
    @IBOutlet weak var img_thumbnail: UIImageView!
    
    @IBOutlet weak var lbl_videoName: UILabel!
    @IBOutlet weak var lbl_time: UILabel!
    
    var thumbnailLoadingTask: Task<Void, Never>?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.setUpUI()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.thumbnailLoadingTask?.cancel()
        self.img_thumbnail.image = nil
    }
    
    func setUpUI() {
        self.img_thumbnail.setCorder(radius: 12)
        self.view_duration.setCorder(radius: 5)
    }
    
}
