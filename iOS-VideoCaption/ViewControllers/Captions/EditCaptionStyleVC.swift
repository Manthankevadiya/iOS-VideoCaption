//
//  EditCaptionStyleVC.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 24/11/25.
//

import UIKit
import Hero
import SwiftUI
import CoreData

class EditCaptionStyleVC: UIViewController {
    
    @IBOutlet weak var lbl_caption: UILabel!
    @IBOutlet weak var picker_font: UIPickerView!
    
    @IBOutlet weak var slider_fontSize: UISlider!
    @IBOutlet weak var btn_animationStyle: UIButton!
    @IBOutlet weak var btn_font: UIButton!
    @IBOutlet weak var btn_fontColour: UIButton!
    
    @IBOutlet var view_allCaptionContainer: [UIView]!
    @IBOutlet var lbl_allAnimatedCaptions: [UILabel]!
    
    @IBOutlet weak var view_fontContainer: UIView!
    @IBOutlet weak var view_animationStyleContainer: UIView!
    @IBOutlet weak var view_fontColourContainer: UIView!
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var segment_colours: UISegmentedControl!
    @IBOutlet weak var cv_colours: UICollectionView!
    
    @IBOutlet weak var slider_textborder: UISlider!
    
    // MARK: Varibales
    var selectedEditStyle : EditCaptionType = .animationStyle
    var selectedColourType : CaptionColorType = .fontColor
    
    private let captionAnimationStyles: [TextAnimationStyle] = [
        .normal,
        .fadeWord,
        .popWord,
        .shrinkPopWord,
        .slideUpWord,
        .slideDownWord,
        .typewriterNormal,
        .typewriterUnderScoreCurser,
        .highlighSingleWord,
        .highlighTrail,
        .highlighByUnderline,
        .highlighByBackground
    ]
    
    var project: CaptionEntity!
    let demoWordDuration: TimeInterval = 0.45
    var selectedAnimationIndex = 0
    var selectedFont: UIFont?
    var selectedFontSize = CGFloat()
    var selectedFontColour = String()
    var selectedHighlightColour = String()
    var selectedBorderColour = String()
    var selectedShadowColour = String()
    var selectedShadhowRadius = CGFloat()
    var selectedBorderSize = CGFloat()
    
    var fontNames: [String] = {
        var names: [String] = []
        for family in UIFont.familyNames.sorted() {
            for name in UIFont.fontNames(forFamilyName: family).sorted() {
                names.append(name)
            }
        }
        return names
    }()
    
    var colourNames = allHexColors
    var clickedOnDone: (()->())?
    var context: NSManagedObjectContext!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.registerCvXIB()
        self.setUpData()
        self.addGestureInCaptionContainer()
        self.setUpColorTypeSelection()
        self.setUpPickerView()
        self.setUpFontSlider()
        self.setUpBorderSlider()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.setSelctedCaptionContainer()
        self.setCaptionAnimation()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.lbl_caption.normalTextedLabel()
        
        for label in self.lbl_allAnimatedCaptions{
            label.normalTextedLabel()
        }
    }
    
    func setUpData() {
        self.slider_textborder.addTarget(self,action: #selector(borderShadowSliderChanged(_:)),for: .valueChanged)
        
        self.selectedFontSize = CGFloat(self.project.captionFontSize)
        self.selectedBorderSize = CGFloat(self.project.borderThickness)
        self.selectedFont = UIFont(name: self.project.captionFontName ?? "", size: self.selectedFontSize)
        
        self.selectedFontColour = self.project.captionFontColor ?? ""
        self.selectedHighlightColour = self.project.captionHighlightColor ?? ""
        self.selectedBorderColour = self.project.borderColor ?? ""
        self.selectedShadowColour = self.project.shadowColor ?? ""
        self.selectedShadhowRadius = CGFloat(self.project.shadowRadius)
        
        self.lbl_caption.font = self.selectedFont?.withSize(self.selectedFontSize)
        self.lbl_caption.layer.borderWidth = self.selectedBorderSize
        self.lbl_caption.textColor = UIColor(hex: self.selectedFontColour)
        
        self.hero.isEnabled = true
        self.lbl_caption.heroID = "captionLabel"
        
        if let savedTypeRaw = self.project.captionAnimationType,
           let savedType = TextAnimationStyle(rawValue: savedTypeRaw),
           let idx = self.captionAnimationStyles.firstIndex(of: savedType) {
            self.selectedAnimationIndex = idx
        } else {
            self.selectedAnimationIndex = 0
        }
        
        DispatchQueue.main.async {
            self.cv_colours.reloadData()
            self.scrollToSelectedColour()
            self.setCaptionAnimation()
            self.setSelctedCaptionContainer()
            self.scrollToSelectedAnimation()
        }
    }
    
    private func scrollToSelectedAnimation() {
        guard self.selectedAnimationIndex >= 0,
              self.selectedAnimationIndex < self.view_allCaptionContainer.count else { return }
        
        self.view.layoutIfNeeded()
        
        let targetView = self.view_allCaptionContainer[self.selectedAnimationIndex]
        let targetFrame = self.scrollView.convert(targetView.frame, from: targetView.superview)
        
        let topPadding: CGFloat = 20
        let desiredOffsetY = targetFrame.origin.y - topPadding
        
        let maxOffsetY = max(0, self.scrollView.contentSize.height - self.scrollView.bounds.height)
        let finalOffsetY = max(0, min(desiredOffsetY, maxOffsetY))
        self.scrollView.setContentOffset(CGPoint(x: 0, y: finalOffsetY), animated: true)
    }
    
    func addGestureInCaptionContainer() {
        for (index, view) in self.view_allCaptionContainer.enumerated() {
            view.layer.cornerRadius = 12
            view.tag = index
            self.addTap(on: view)
        }
        
        for (index, label) in self.lbl_allAnimatedCaptions.enumerated() {
            label.tag = index
            label.textColor = UIColor(hex: self.selectedFontColour)
            label.font = self.selectedFont?.withSize(20)
        }
    }
    
    func addTap(on v: UIView) {
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        v.addGestureRecognizer(tap)
    }
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view else { return }
        let index = view.tag
        guard index != selectedAnimationIndex else { return }
        
        selectedAnimationIndex = index
        setSelctedCaptionContainer()
        scrollToSelectedAnimation()
    }
    
    // MARK: - Core Logic Functions
    func setSelctedCaptionContainer() {
        
        guard !self.view_allCaptionContainer.isEmpty,
              !self.captionAnimationStyles.isEmpty,
              self.selectedAnimationIndex >= 0,
              self.selectedAnimationIndex < self.captionAnimationStyles.count else { return }
        
        for view in self.view_allCaptionContainer {
            let isSelected = self.selectedAnimationIndex == view.tag
            view.layer.borderColor = isSelected ? UIColor.color8137FF.cgColor : UIColor.clear.cgColor
            view.layer.borderWidth = isSelected ? 2 : 0
        }
        
        let selectedStyle = captionAnimationStyles[self.selectedAnimationIndex]
        let captionText = self.lbl_caption.text ?? "Hey there, it's caption!"
        let fontName = self.lbl_caption.font.fontName
        let fontColor = self.lbl_caption.textColor
        let highlightColor = UIColor(hex: self.selectedHighlightColour)
        
        switch selectedStyle {
        case .highlighSingleWord, .highlighTrail, .highlighByUnderline, .highlighByBackground:
            self.lbl_caption.animateText(
                captionText,
                style: selectedStyle,
                highlightColor: highlightColor,
                isDemo: true,
                wordDuration: demoWordDuration,
                fontSize: self.selectedFontSize,
                borderWidth: selectedBorderSize,
                borderColor: UIColor(hex: self.selectedBorderColour),
                shadowColor: UIColor(hex: self.selectedShadowColour),
                shadowRadius: self.selectedShadhowRadius,
                fontName: fontName,
                fontColor: fontColor
            )
        default:
            self.lbl_caption.animateText(
                captionText,
                style: selectedStyle,
                isDemo: true,
                wordDuration: demoWordDuration,
                fontSize: self.selectedFontSize,
                borderWidth: selectedBorderSize,
                borderColor: UIColor(hex: self.selectedBorderColour),
                shadowColor: UIColor(hex: self.selectedShadowColour),
                shadowRadius: self.selectedShadhowRadius,
                fontName: fontName,
                fontColor: fontColor
            )
        }
    }
    
    func setCaptionAnimation() {
        
        guard !self.lbl_allAnimatedCaptions.isEmpty else { return }
        
        let highlightColor = UIColor(hex: self.selectedHighlightColour)
        
        for (index, label) in self.lbl_allAnimatedCaptions.enumerated() {
            label.textColor = UIColor(hex: self.selectedFontColour)
            label.font = self.selectedFont?.withSize(20)
            
            guard label.tag >= 0 && label.tag < self.captionAnimationStyles.count else {
                label.normalTextedLabel()
                if index < self.view_allCaptionContainer.count {
                    self.view_allCaptionContainer[index].isHidden = true
                } else {
                    self.view_allCaptionContainer[index].isHidden = false
                }
                continue
            }
            
            let selectedStyle = self.captionAnimationStyles[label.tag]
            let captionText = label.text ?? "Hey there, it's caption!"
            
            switch selectedStyle {
            case .highlighSingleWord, .highlighTrail, .highlighByUnderline, .highlighByBackground:
                label.animateText(
                    captionText,
                    style: selectedStyle,
                    highlightColor: highlightColor,
                    isDemo: true,
                    wordDuration: demoWordDuration,
                    fontSize: 20
                )
            default:
                label.animateText(
                    captionText,
                    style: selectedStyle,
                    isDemo: true,
                    wordDuration: demoWordDuration
                )
            }
        }
    }
    
    func setUpFontSlider() {
        self.slider_fontSize.minimumValue = 16
        self.slider_fontSize.maximumValue = 35
        self.slider_fontSize.value = Float(self.selectedFontSize)
        self.slider_fontSize.addTarget(self, action: #selector(self.fontSizeSliderChanged(_:)), for: .valueChanged)
    }
    
    func setUpBorderSlider() {
        switch segment_colours.selectedSegmentIndex {
        case 2: // Border
            slider_textborder.minimumValue = 0
            slider_textborder.maximumValue = 2
            slider_textborder.value = Float(selectedBorderSize)
            
        case 3: // Shadow
            slider_textborder.minimumValue = 0
            slider_textborder.maximumValue = 5
            slider_textborder.value = Float(selectedShadhowRadius)
            
        default:
            break
        }
    }
    
    @objc func fontSizeSliderChanged(_ sender: UISlider) {
        selectedFontSize = CGFloat(sender.value)
        lbl_caption.font = selectedFont?.withSize(selectedFontSize)
        setSelctedCaptionContainer()
    }
    
    @objc func borderShadowSliderChanged(_ sender: UISlider) {
        switch segment_colours.selectedSegmentIndex {
        case 2: selectedBorderSize = CGFloat(sender.value)
        case 3: selectedShadhowRadius = CGFloat(sender.value)
        default: return
        }
        
        setSelctedCaptionContainer()
    }
    
    @IBAction func clickOnCaptionAnimation(_ sender: Any) {
        self.selectedEditStyle = .animationStyle
        self.setUpColorTypeSelection()
    }
    
    @IBAction func clickOnFonts(_ sender: Any) {
        self.selectedEditStyle = .font
        self.setUpColorTypeSelection()
    }
    
    @IBAction func clickOnCaptionColous(_ sender: Any) {
        self.selectedEditStyle = .fontColor
        self.setUpColorTypeSelection()
    }
    
    @IBAction func clickOnSegment(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            self.selectedColourType = .fontColor
            self.slider_textborder.isHidden = true
        case 1:
            self.selectedColourType = .highlightColor
            self.slider_textborder.isHidden = true
        case 2:
            self.selectedColourType = .borderColor
            self.slider_textborder.isHidden = false
        case 3:
            self.selectedColourType = .shadowColor
            self.slider_textborder.isHidden = false
        default:
            break
        }
        self.cv_colours.reloadData()
        self.setUpBorderSlider()
        self.scrollToSelectedColour()
    }
    
    @IBAction func clickOnCancel(_ sender: Any) {
        self.dismiss(animated: true)
    }
    
    @IBAction func clickOnDone(_ sender: Any) {
//        CoreDataManager.shared.updateCaptionStyle(project: self.project, fontName: self.selectedFont?.fontName ?? "", fontSize: Float(self.selectedFontSize), fontColor: self.selectedFontColour, fontHighlightColor: self.selectedHighlightColour, animationType: captionAnimationStyles[self.selectedAnimationIndex].rawValue, borderColor: self.selectedBorderColour, borderThick: Float(self.selectedBorderSize), shadowradius: Float(selectedShadhowRadius), shadowColor: self.selectedShadowColour)
//        self.clickedOnDone?()
//        self.dismiss(animated: true)
        
        
        guard let project = self.project else { return }
        let context = self.context!
        
        // ✅ BEGIN GROUP (so 1 undo = whole edit session)
        context.undoManager?.beginUndoGrouping()
        
        // Capture old values for undo
        let oldFontName = project.captionFontName
        let oldFontSize = project.captionFontSize
        let oldFontColor = project.captionFontColor
        let oldHighlightColor = project.captionHighlightColor
        let oldAnimation = project.captionAnimationType
        let oldBorderColor = project.borderColor
        let oldBorderSize = project.borderThickness
        let oldShadowRadius = project.shadowRadius
        let oldShadowColor = project.shadowColor
        
        // ✅ REGISTER UNDO
        context.undoManager?.registerUndo(withTarget: project) { target in
            target.captionFontName = oldFontName
            target.captionFontSize = oldFontSize
            target.captionFontColor = oldFontColor
            target.captionHighlightColor = oldHighlightColor
            target.captionAnimationType = oldAnimation
            target.borderColor = oldBorderColor
            target.borderThickness = oldBorderSize
            target.shadowRadius = oldShadowRadius
            target.shadowColor = oldShadowColor
        }
        
        // ✅ APPLY NEW VALUES
        project.captionFontName = self.selectedFont?.fontName
        project.captionFontSize = Float(self.selectedFontSize)
        project.captionFontColor = self.selectedFontColour
        project.captionHighlightColor = self.selectedHighlightColour
        project.captionAnimationType = captionAnimationStyles[self.selectedAnimationIndex].rawValue
        project.borderColor = self.selectedBorderColour
        project.borderThickness = Float(self.selectedBorderSize)
        project.shadowRadius = Float(self.selectedShadhowRadius)
        project.shadowColor = self.selectedShadowColour
        
        // ✅ SAVE
        CoreDataManager.shared.saveContext()
        
        // ✅ END GROUP
        context.undoManager?.endUndoGrouping()
        
        // Notify home page to refresh UI
        self.clickedOnDone?()
        
        self.dismiss(animated: true)
        
    }
}

extension EditCaptionStyleVC {
    
    func setUpColorTypeSelection() {
        switch self.selectedEditStyle {
        case .animationStyle:
            self.btn_animationStyle.tintColor = .color8137FF
            self.btn_font.tintColor = .colorFFFFFF
            self.btn_fontColour.tintColor = .colorFFFFFF
            
            self.view_animationStyleContainer.isHidden = false
            self.view_fontContainer.isHidden = true
            self.view_fontColourContainer.isHidden = true
        case .font:
            self.btn_animationStyle.tintColor = .colorFFFFFF
            self.btn_font.tintColor = .color8137FF
            self.btn_fontColour.tintColor = .colorFFFFFF
            
            self.view_animationStyleContainer.isHidden = true
            self.view_fontContainer.isHidden = false
            self.view_fontColourContainer.isHidden = true
        case .fontColor:
            self.btn_animationStyle.tintColor = .colorFFFFFF
            self.btn_font.tintColor = .colorFFFFFF
            self.btn_fontColour.tintColor = .color8137FF
            
            self.view_animationStyleContainer.isHidden = true
            self.view_fontContainer.isHidden = true
            self.view_fontColourContainer.isHidden = false
        }
    }
    
    func setUpPickerView() {
        self.picker_font.dataSource = self
        self.picker_font.delegate = self
        
        let fontName = self.project.captionFontName ?? ""
        
        if let defaultIndex = self.fontNames.firstIndex(of: fontName) {
            self.picker_font.selectRow(defaultIndex, inComponent: 0, animated: false)
            
            self.lbl_caption.font = UIFont(name: fontName, size: self.selectedFontSize)
        } else {
            self.lbl_caption.font = UIFont(name: fontName, size: self.selectedFontSize)
        }
    }
}

extension EditCaptionStyleVC: UIPickerViewDelegate, UIPickerViewDataSource {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.fontNames.count
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let fontName = self.fontNames[row]
        
        let pickerLabel = view as? UILabel ?? UILabel()
        
        pickerLabel.text = fontName
        pickerLabel.textAlignment = .center
        pickerLabel.adjustsFontSizeToFitWidth = true
        
        if let customFont = UIFont(name: fontName, size: self.selectedFontSize) {
            pickerLabel.font = customFont
        } else {
            pickerLabel.font = UIFont.systemFont(ofSize: self.selectedFontSize)
        }
        
        return pickerLabel
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let selectedFontName = self.fontNames[row]
        self.selectedFont = UIFont(name: selectedFontName, size: self.selectedFontSize)
        self.lbl_caption.font = self.selectedFont
        self.setSelctedCaptionContainer()
    }
    
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        let desiredHeight: CGFloat = 40
        return desiredHeight
    }
    
}

extension EditCaptionStyleVC {
    
    func registerCvXIB() {
        self.cv_colours.delegate = self
        self.cv_colours.dataSource = self
        self.cv_colours.register(UINib(nibName: "ColorCvCell", bundle: nil), forCellWithReuseIdentifier: "ColorCvCell")
        self.cv_colours.decelerationRate = .fast
    }
    
    func scrollToSelectedColour() {
        var index: Int?
        
        switch self.selectedColourType {
        case .fontColor:
            index = self.colourNames.firstIndex(where: { $0 == self.selectedFontColour })
        case .highlightColor:
            index = self.colourNames.firstIndex(where: { $0 == self.selectedHighlightColour })
        case .borderColor:
            index = self.colourNames.firstIndex(where: { $0 == self.selectedBorderColour })
        case .shadowColor:
            index = self.colourNames.firstIndex(where: { $0 == self.selectedShadowColour })
        }
        
        guard let idx = index else { return }
        
        let indexPath = IndexPath(item: idx, section: 0)
        self.cv_colours.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
    }
    
}

extension EditCaptionStyleVC: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.colourNames.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = self.cv_colours.dequeueReusableCell(withReuseIdentifier: "ColorCvCell", for: indexPath) as! ColorCvCell
        let obj = self.colourNames[indexPath.row]
        var isSelected = false
        
        switch self.selectedColourType {
        case .fontColor:
            isSelected = self.selectedFontColour == self.colourNames[indexPath.row]
        case .highlightColor:
            isSelected = self.selectedHighlightColour == self.colourNames[indexPath.row]
        case .borderColor:
            isSelected = self.selectedBorderColour == self.colourNames[indexPath.row]
        case .shadowColor:
            isSelected = self.selectedShadowColour == self.colourNames[indexPath.row]
        }
        
        cell.configure(with: obj, isSelected: isSelected)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch self.selectedColourType {
        case .fontColor:
            self.selectedFontColour = self.colourNames[indexPath.row]
        case .highlightColor:
            self.selectedHighlightColour = self.colourNames[indexPath.row]
        case .borderColor:
            self.selectedBorderColour = self.colourNames[indexPath.row]
        case .shadowColor:
            self.selectedShadowColour = self.colourNames[indexPath.row]
        }
        
        self.lbl_caption.textColor = UIColor(hex: self.selectedFontColour)
        setSelctedCaptionContainer()
        self.cv_colours.reloadData()
    }
}
