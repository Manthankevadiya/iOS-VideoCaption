//
//  HistoryVC.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 27/10/25.
//

import UIKit
import AVFoundation

class HistoryVC: UIViewController {
    
    @IBOutlet weak var cv_history: UICollectionView!
    @IBOutlet weak var btn_menu: UIButton!
    
    @IBOutlet weak var view_noData: UIView!
    
    var selectedAction: VideoActionType?
    var arr_history = [CaptionEntity]()
    
    var timer: Timer?
    private let refreshControl = UIRefreshControl()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.registerXIB()
        self.setUpMenuBtn()
        self.setUpRefreshControl()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setUpData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateVisibleTimeLabels()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.timer?.invalidate()
        self.timer = nil
    }
    
    func registerXIB() {
        self.cv_history.delegate = self
        self.cv_history.dataSource = self
        self.cv_history.register(UINib(nibName: "HistoryCvCell", bundle: nil), forCellWithReuseIdentifier: "HistoryCvCell")
    }
    
    func setUpData() {
        self.arr_history = CoreDataManager.shared.fetchAllProjects()
        
        if self.arr_history.isEmpty || self.arr_history.count == 0 {
            self.view_noData.isHidden = false
        } else {
            self.view_noData.isHidden = true
        }
        
        self.cv_history.reloadData()
    }
    
    func setUpMenuBtn() {
        let actions: [(title: String, image: UIImage?, type: VideoActionType)] = [
            ("Trim", .icTrim, .trim),
            ("Crop", .icCrop, .crop),
            ("Compress", .icCompress, .compress),
            ("Caption", .icCaption, .caption)
        ]
        
        let menuChildren = actions.map { item in
            UIAction(title: item.title, image: item.image) { _ in
                self.selectedAction = item.type
                self.presentPickVideoPopup()
            }
        }
        
        self.btn_menu.menu = UIMenu(title: "", children: menuChildren)
        self.btn_menu.showsMenuAsPrimaryAction = true
    }
    
    func setUpRefreshControl() {
        self.refreshControl.addTarget(self, action: #selector(handleRefresh(_:)), for: .valueChanged)
        self.cv_history.refreshControl = self.refreshControl
    }
    
    @objc func handleRefresh(_ sender: UIRefreshControl) {
        self.setUpData()
        sender.endRefreshing()
    }
    
    func presentPickVideoPopup() {
        let vc = PickVideoPopUp.instantiate()
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        
        vc.clickSelect = { wantToRecord in
            if wantToRecord {
                self.openCamera()
            } else {
                self.openVideoPicker()
            }
        }
        
        self.present(vc, animated: true)
    }
    
    func updateVisibleTimeLabels() {
        let visibleIndexPaths = self.cv_history.indexPathsForVisibleItems
        
        for indexPath in visibleIndexPaths {
            guard let cell = self.cv_history.cellForItem(at: indexPath) as? HistoryCvCell else {
                continue
            }
            
            let objProject = self.arr_history[indexPath.row]
            
            if let edited = objProject.dateLastEdited {
                cell.lbl_time.text = timeAgoString(from: edited)
            } else if let created = objProject.dateCreated {
                cell.lbl_time.text = timeAgoString(from: created)
            } else {
                cell.lbl_time.text = ""
            }
        }
    }
    
    private func showRenameAlert(for project: CaptionEntity) {
        let alert = UIAlertController(title: "Rename Video", message: "Enter a new name for the video.", preferredStyle: .alert)
        
        alert.addTextField { textField in
            // Pre-fill the text field with the current name (excluding extension)
            let currentName = project.videoName?.components(separatedBy: ".").first ?? ""
            textField.text = currentName
        }
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self,
                  let newName = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !newName.isEmpty else { return }
            
            self.performRename(for: project, newName: newName)
        }
        
        alert.addAction(saveAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alert, animated: true)
    }
    
    private func performRename(for project: CaptionEntity, newName: String) {
        guard let oldURL = project.currentAbsoluteVideoURL else {
            print("Error: Cannot rename, old file URL not found.")
            return
        }
        
        let fileExtension = oldURL.pathExtension
        let newFileName = "\(newName).\(fileExtension)"
        
        // 1. Construct the new URL in the Documents directory
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let newURL = documentsDirectory.appendingPathComponent(newFileName)
        
        do {
            // 2. Rename (move) the physical file on disk
            try FileManager.default.moveItem(at: oldURL, to: newURL)
            
            // 3. Update Core Data
            project.videoName = newFileName
            project.videoLink = newFileName
            project.dateLastEdited = Date()
            CoreDataManager.shared.saveContext()
            
            print("✅ Successfully renamed to: \(newFileName)")
            
            // 4. Reload the UI
            self.setUpData()
        } catch {
            print("❌ Error renaming file from \(oldURL.lastPathComponent) to \(newFileName): \(error.localizedDescription)")
        }
    }
    
    private func confirmAndDeleteProject(_ project: CaptionEntity) {
        let alert = UIAlertController(title: "Delete Project",
                                      message: "Are you sure you want to delete '\(project.videoName ?? "this project")'? This action cannot be undone.",
                                      preferredStyle: .alert)
        
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            
            // 1. Delete the physical file
            if let url = project.currentAbsoluteVideoURL {
                do {
                    try FileManager.default.removeItem(at: url)
                    print("🗑️ Deleted single video file: \(url.lastPathComponent)")
                } catch {
                    print("Error deleting single file: \(error.localizedDescription)")
                }
            }
            
            // 2. Delete from Core Data
            CoreDataManager.shared.deleteProject(project)
            
            // 3. Update the local data source and UI
            self.setUpData()
        }
        
        alert.addAction(deleteAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alert, animated: true)
    }
    
    func makePreviewForCell(at indexPath: IndexPath) -> UIViewController? {
        let previewVC = UIViewController()
        
        let cell = self.cv_history.cellForItem(at: indexPath) as! HistoryCvCell
        let snapshot = cell.snapshotView(afterScreenUpdates: false) ?? UIView()
        snapshot.layer.cornerRadius = 12
        snapshot.clipsToBounds = true
        
        previewVC.view = snapshot
        previewVC.preferredContentSize = CGSize(width: 220, height: 300)  // bigger preview size
        
        return previewVC
    }
   
    func makeMenuFor(project: CaptionEntity) -> UIMenu {

        let rename = UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { _ in
            self.showRenameAlert(for: project)
        }
        
        let delete = UIAction(title: "Delete",
                              image: UIImage(systemName: "trash"),
                              attributes: .destructive) { _ in
            self.confirmAndDeleteProject(project)
        }
        
        return UIMenu(title: "", children: [rename, delete])
    }
    
}

extension HistoryVC: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.arr_history.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = self.cv_history.dequeueReusableCell(withReuseIdentifier: "HistoryCvCell", for: indexPath) as! HistoryCvCell
        
        let objProject = self.arr_history[indexPath.row]
        
        cell.lbl_videoName.text = objProject.videoName
        
        let rawDuration = objProject.totalDuration
        let formattedDuration = formatDuration(seconds: rawDuration)
        cell.lbl_duration.text = formattedDuration
        
        if let edited = objProject.dateLastEdited {
            cell.lbl_time.text = timeAgoString(from: edited)
        } else if let created = objProject.dateCreated {
            cell.lbl_time.text = timeAgoString(from: created)
        } else {
            cell.lbl_time.text = ""
        }
        
        if let imageData = objProject.videoThumbnail,
           let image = UIImage(data: imageData) {
            cell.img_thumbnail.image = image
        } else {
            cell.img_thumbnail.image = nil
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) {
            let obj = self.arr_history[indexPath.row]
            
            guard let project = CoreDataManager.shared.fetchProject(byID: obj.videoID ?? UUID()) else {
                print("m̐ Project not found !!!")
                return
            }
            
            cell.pressAnimation {
                if (obj.fullCaptionText?.count ?? 0) > 0 {
                    let vc = CaptionVC.instantiate()
                    vc.project = project
                    self.pushVC(vc: vc, animation: true)
                } else {
                    let vc = SelectLanguageVC.instantiate()
                    vc.project = project
                    self.pushVC(vc: vc, animation: true)
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        
        let project = self.arr_history[indexPath.row]
        
        return UIContextMenuConfiguration(identifier: indexPath as NSCopying,
                                          previewProvider: {
            return self.makePreviewForCell(at: indexPath)
        },
                                          actionProvider: { _ in
            return self.makeMenuFor(project: project)
        })
    }
    
}

extension HistoryVC: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Spacing setup
        let inset: CGFloat = 20
        let interItemSpacing: CGFloat = 20
        
        // Calculate total horizontal padding
        let totalSpacing = (inset * 2) + interItemSpacing
        let availableWidth = collectionView.bounds.width - totalSpacing
        
        // 2 items per row
        let cellWidth = availableWidth / 2
        
        // Adjust height based on desired proportion (1.25 gives a nice card look)
        return CGSize(width: cellWidth, height: cellWidth + 58)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 20 // spacing between rows
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 20 // spacing between columns
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
    }
}

extension HistoryVC: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            print("Camera not available")
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.movie"]
        picker.delegate = self
        picker.videoQuality = .typeHigh
        self.present(picker, animated: true)
    }
    
    func openVideoPicker() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.movie"]
        picker.delegate = self
        self.present(picker, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        guard let videoURL = info[.mediaURL] as? URL else { return }
        
        switch selectedAction {
        case .trim:
//            let vc = TrimVideoVC.instantiate()
//            vc.videoURL = videoURL
//            self.navigationController?.pushViewController(vc, animated: true)
            return
        case .crop:
//            let vc = CropVideoVC.instantiate()
//            vc.videoURL = videoURL
//            self.navigationController?.pushViewController(vc, animated: true)
            return
        case .compress:
//            let vc = CompressVideoVC.instantiate()
//            vc.videoURL = videoURL
//            self.navigationController?.pushViewController(vc, animated: true)
            return
        case .caption:
            
            guard let permanentVideoURL = saveVideoToDocuments(from: videoURL) else {
                print("Error: Failed to secure video file.")
                return
            }
            
            // 1. Get the vid eo asset and duration
            let asset = AVAsset(url: permanentVideoURL)
            let totalDurationSeconds = CMTimeGetSeconds(asset.duration)
            
            // 2. Determine the video name and link
            var rawVideoName = permanentVideoURL.lastPathComponent
            let relativeLink = permanentVideoURL.lastPathComponent
            
            let unwantedPrefix = "trim."
            if rawVideoName.lowercased().hasPrefix(unwantedPrefix.lowercased()) {
                // Strip the prefix
                rawVideoName = String(rawVideoName.dropFirst(unwantedPrefix.count))
                
                // If the name is now empty, fallback to a default
                if rawVideoName.isEmpty {
                    rawVideoName = "Video_\(Date().timeIntervalSince1970).MOV"
                }
            }
            
            // 3. Create the new Core Data project
            let newProject = CoreDataManager.shared.createNewProject(
                name: rawVideoName,
                link: relativeLink,
                duration: totalDurationSeconds
            )
            
            // 4. Navigate to the next screen, passing the created project object
            let vc = SelectLanguageVC.instantiate()
            vc.project = newProject
            self.pushVC(vc: vc, animation: true)
            
        default:
            break
        }
    }
    
}
