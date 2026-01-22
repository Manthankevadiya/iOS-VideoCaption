//
//  GlobalUndoManager.swift
//  iOS-VideoCaption
//
//  Created by Social Infotech on 22/01/26.
//

import Foundation
import UIKit

extension Notification.Name {
    static let UndoManagerDidChange = Notification.Name("UndoManagerDidChange")
}

class GlobalUndoManager {
    static let shared = GlobalUndoManager()
    let undoManager = UndoManager()
    
    private init() {
        // Observe changes in the undo manager
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUndoManagerChange),
            name: .NSUndoManagerDidUndoChange,
            object: undoManager
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUndoManagerChange),
            name: .NSUndoManagerDidRedoChange,
            object: undoManager
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUndoManagerChange),
            name: .NSUndoManagerWillCloseUndoGroup,
            object: undoManager
        )
    }
    
    @objc private func handleUndoManagerChange() {
        // Notify observers that undo/redo availability may have changed
        NotificationCenter.default.post(name: .UndoManagerDidChange, object: nil)
    }
}
