//
//  WordCvCell.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 05/01/26.
//

import UIKit

final class WordCvCell: UICollectionViewCell, UITextFieldDelegate {
    static let reuse = "WordCvCell"
    
    private let label = UILabel()
    private let textField = UITextField()
    
    var onRenameCommit: ((String) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentView.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        contentView.layer.cornerRadius = 6
        contentView.layer.masksToBounds = true
        
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        
        textField.font = label.font
        textField.textColor = .white
        textField.textAlignment = .center
        textField.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        textField.isHidden = true
        textField.delegate = self
        textField.returnKeyType = .done
        
        [label, textField].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
            NSLayoutConstraint.activate([
                $0.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
                $0.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
                $0.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
            ])
        }
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(text: String, selected: Bool) {
        label.text = text
        textField.text = text
        
        contentView.layer.borderWidth = selected ? 2 : 0
        contentView.layer.borderColor = selected ? UIColor.systemYellow.cgColor : UIColor.clear.cgColor
    }
    
    func beginRename() {
        label.isHidden = true
        textField.isHidden = false
        textField.becomeFirstResponder()
        textField.selectAll(nil)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        commitRename()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        commitRename()
    }
    
    private func commitRename() {
        let newText = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        textField.resignFirstResponder()
        textField.isHidden = true
        label.isHidden = false
        if !newText.isEmpty { onRenameCommit?(newText) }
    }
}
