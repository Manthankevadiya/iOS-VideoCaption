//
//  WordRenamePanelView.swift
//  iOS-VideoCaption
//

import UIKit
import CoreData

protocol WordRenamePanelDelegate: AnyObject {
    func wordRenamePanelDidSave(_ panel: WordRenamePanelView, newText: String, index: Int, objectID: NSManagedObjectID?)
    func wordRenamePanelDidCancel(_ panel: WordRenamePanelView)
}

class WordRenamePanelView: UIView {
    
    weak var delegate: WordRenamePanelDelegate?
    
    private let containerView = UIView()
    private let textField = UITextField()
    private let collectionView: UICollectionView
    private let saveButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    
    private var wordSegments: [WordSegment] = []
    private var selectedIndex: Int = 0
    private var objectID: NSManagedObjectID?
    
    private var keyboardHeight: CGFloat = 0
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        super.init(frame: frame)
        setupUI()
        setupKeyboardObservers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.7)
        
        // Container View
        containerView.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        containerView.layer.cornerRadius = 12
        containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        
        // TextField
        textField.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        textField.textColor = .white
        textField.font = .systemFont(ofSize: 17, weight: .medium)
        textField.textAlignment = .center
        textField.layer.cornerRadius = 8
        textField.returnKeyType = .done
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        // Add padding to textfield
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 40))
        textField.leftView = paddingView
        textField.leftViewMode = .always
        textField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 40))
        textField.rightViewMode = .always
        
        containerView.addSubview(textField)
        
        // Buttons Container
        let buttonStack = UIStackView()
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(buttonStack)
        
        // Cancel Button
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        cancelButton.backgroundColor = UIColor(white: 0.25, alpha: 1.0)
        cancelButton.layer.cornerRadius = 8
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        buttonStack.addArrangedSubview(cancelButton)
        
        // Save Button
        saveButton.setTitle("Save", for: .normal)
        saveButton.setTitleColor(.black, for: .normal)
        saveButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        saveButton.backgroundColor = .white
        saveButton.layer.cornerRadius = 8
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        buttonStack.addArrangedSubview(saveButton)
        
        // Collection View
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(WordRenameCvCell.self, forCellWithReuseIdentifier: WordRenameCvCell.reuse)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(collectionView)
        
        // Constraints
        NSLayoutConstraint.activate([
            // Container View - Initially positioned below screen
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 200),
            
            // TextField
            textField.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            textField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            textField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            textField.heightAnchor.constraint(equalToConstant: 44),
            
            // Button Stack
            buttonStack.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 12),
            buttonStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            buttonStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            buttonStack.heightAnchor.constraint(equalToConstant: 44),
            
            // Collection View
            collectionView.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    // MARK: - Public Methods
    
    func show(in view: UIView, segments: [WordSegment], selectedIndex: Int, objectID: NSManagedObjectID?) {
        self.wordSegments = segments
        self.selectedIndex = selectedIndex
        self.objectID = objectID
        
        guard selectedIndex < segments.count else { return }
        
        textField.text = segments[selectedIndex].text
        
        frame = view.bounds
        view.addSubview(self)
        
        // Initial state - container off screen
        containerView.transform = CGAffineTransform(translationX: 0, y: 200)
        alpha = 0
        
        // Animate in
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.alpha = 1
            self.containerView.transform = .identity
        } completion: { _ in
            self.textField.becomeFirstResponder()
            self.collectionView.reloadData()
            self.scrollToSelectedWord(animated: false)
        }
    }
    
    func dismiss(animated: Bool = true) {
        textField.resignFirstResponder()
        
        if animated {
            UIView.animate(withDuration: 0.25, animations: {
                self.alpha = 0
                self.containerView.transform = CGAffineTransform(translationX: 0, y: 200)
            }) { _ in
                self.removeFromSuperview()
            }
        } else {
            removeFromSuperview()
        }
    }
    
    // MARK: - Actions
    
    @objc private func saveTapped() {
        guard let newText = textField.text?.trimmingCharacters(in: .whitespaces),
              !newText.isEmpty else {
            // Show error or just dismiss
            return
        }
        
        delegate?.wordRenamePanelDidSave(self, newText: newText, index: selectedIndex, objectID: objectID)
        dismiss()
    }
    
    @objc private func cancelTapped() {
        delegate?.wordRenamePanelDidCancel(self)
        dismiss()
    }
    
    // MARK: - Keyboard Handling
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        keyboardHeight = keyboardFrame.height
        
        // Animate container above keyboard
        UIView.animate(withDuration: 0.3) {
            self.containerView.transform = CGAffineTransform(translationX: 0, y: -self.keyboardHeight)
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        UIView.animate(withDuration: 0.3) {
            self.containerView.transform = .identity
        }
    }
    
    private func scrollToSelectedWord(animated: Bool) {
        guard selectedIndex < wordSegments.count else { return }
        
        let indexPath = IndexPath(item: selectedIndex, section: 0)
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: animated)
    }
}

// MARK: - UITextFieldDelegate

extension WordRenamePanelView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        saveTapped()
        return true
    }
}

// MARK: - UICollectionViewDataSource

extension WordRenamePanelView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return wordSegments.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: WordRenameCvCell.reuse, for: indexPath) as! WordRenameCvCell
        
        let segment = wordSegments[indexPath.item]
        let isSelected = indexPath.item == selectedIndex
        
        cell.configure(text: segment.text, isSelected: isSelected)
        
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension WordRenamePanelView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let oldIndex = selectedIndex
        selectedIndex = indexPath.item
        objectID = wordSegments[indexPath.item].objectID
        
        textField.text = wordSegments[indexPath.item].text
        
        // Reload affected cells
        collectionView.reloadItems(at: [
            IndexPath(item: oldIndex, section: 0),
            indexPath
        ])
        
        scrollToSelectedWord(animated: true)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension WordRenamePanelView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let text = wordSegments[indexPath.item].text
        let font = UIFont.systemFont(ofSize: 15, weight: .medium)
        let width = (text as NSString).size(withAttributes: [.font: font]).width + 24
        return CGSize(width: max(width, 60), height: 36)
    }
}

// MARK: - WordRenameCvCell

class WordRenameCvCell: UICollectionViewCell {
    static let reuse = "WordRenameCvCell"
    
    private let label = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        contentView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        contentView.layer.cornerRadius = 8
        contentView.layer.borderWidth = 2
        contentView.layer.borderColor = UIColor.clear.cgColor
        
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -12)
        ])
    }
    
    func configure(text: String, isSelected: Bool) {
        label.text = text
        
        if isSelected {
            contentView.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            contentView.layer.borderColor = UIColor.white.cgColor
            label.textColor = .white
        } else {
            contentView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
            contentView.layer.borderColor = UIColor.clear.cgColor
            label.textColor = UIColor.lightGray
        }
    }
}
