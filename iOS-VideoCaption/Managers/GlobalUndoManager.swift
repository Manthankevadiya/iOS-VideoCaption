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
        undoManager.levelsOfUndo = 50 // Increase undo stack size
        
        // Observe ALL undo manager changes
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
            name: .NSUndoManagerDidCloseUndoGroup,
            object: undoManager
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUndoManagerChange),
            name: .NSUndoManagerDidOpenUndoGroup,
            object: undoManager
        )
    }
    
    @objc private func handleUndoManagerChange() {
        NotificationCenter.default.post(name: .UndoManagerDidChange, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
