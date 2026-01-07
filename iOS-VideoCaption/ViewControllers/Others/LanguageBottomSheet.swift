//
//  LanguageBottomSheet.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 03/11/25.
//

import UIKit

class LanguageBottomSheet: UIViewController {

    @IBOutlet weak var view_searchBG: UIView!
    @IBOutlet weak var txt_search: UITextField!
    @IBOutlet weak var btn_continue: UIButton!
    @IBOutlet weak var tbl_languages: UITableView!
    
    let speechLanguages = getSupportedSpeechLanguages()
    var filteredLanguages: [(id: String, name: String)] = []
    var selectedLangCode = String()
    var selectedLangIndex = 0
    
    var clickContinue: (((id: String, name: String))->())?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setUpUI()
        self.setUpTextField()
        self.registerXIB()
        self.preselectEnglish()
    }
    
    func setUpUI() {
        self.filteredLanguages = self.speechLanguages
        
        self.view_searchBG.setCorder(radius: 12)
        self.btn_continue.setCorder(radius: 12)
        self.txt_search.setPlaceholder("Search", color: .colorABABAB, font: .systemFont(ofSize: 16, weight: .medium))
        self.tbl_languages.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 88, right: 0)
    }
    
    func registerXIB() {
        self.tbl_languages.delegate = self
        self.tbl_languages.dataSource = self
        self.tbl_languages.register(UINib(nibName: "LanguageTvCell", bundle: nil), forCellReuseIdentifier: "LanguageTvCell")
    }
    
    func setUpTextField() {
        self.txt_search.delegate = self
        self.txt_search.returnKeyType = .done
        self.txt_search.enablesReturnKeyAutomatically = false
        self.txt_search.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
    }
    
    func preselectEnglish() {
        if let index = self.speechLanguages.firstIndex(where: { $0.id.lowercased().contains(self.selectedLangCode.lowercased()) }) {
            self.selectedLangIndex = index
        } else {
            self.selectedLangIndex = 0 // fallback if not found
        }
        self.tbl_languages.reloadData()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let indexPath = IndexPath(row: self.selectedLangIndex, section: 0)
            self.tbl_languages.scrollToRow(at: indexPath, at: .top, animated: false)
        }
    }
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        let searchText = textField.text?.lowercased() ?? ""
        
        if searchText.isEmpty {
            self.filteredLanguages = self.speechLanguages
        } else {
            self.filteredLanguages = self.speechLanguages.filter {
                $0.name.lowercased().contains(searchText)
            }
        }
        
        self.tbl_languages.reloadData()
    }
    
    @IBAction func clickOnClose(_ sender: Any) {
        self.dismiss(animated: true)
    }
    
    @IBAction func clickOnContinue(_ sender: Any) {
        self.dismiss(animated: true) {
            self.clickContinue?(self.filteredLanguages[self.selectedLangIndex])
        }
    }
    
}

extension LanguageBottomSheet: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

extension LanguageBottomSheet : UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.filteredLanguages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tbl_languages.dequeueReusableCell(withIdentifier: "LanguageTvCell") as! LanguageTvCell
        
        cell.img_tick.isHidden = (indexPath.row != self.selectedLangIndex)
        cell.lbl_lang.text = self.filteredLanguages[indexPath.row].name
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let lastRowIndex = tableView.numberOfRows(inSection: indexPath.section) - 1
        if indexPath.row == lastRowIndex {
            cell.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: .greatestFiniteMagnitude)
        } else {
            cell.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if self.selectedLangIndex != indexPath.row {
            self.selectedLangIndex = indexPath.row
            self.tbl_languages.reloadData()
        }
    }
}
