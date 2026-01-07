//
//  Extensions.swift
//  iOS-VideoCaption
//
//  Created by Manthan Kevadiya on 31/10/25.
//

import UIKit
import AVFoundation

extension UIViewController {
    
    func showAleartPopUp(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        
        // Close action
        alert.addAction(UIAlertAction(title: "Close", style: .cancel, handler: nil))
        
        // Settings action
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString),
                  UIApplication.shared.canOpenURL(settingsURL) else { return }
            UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
        })
        
        self.present(alert, animated: true, completion: nil)
    }
    
}

extension UIView {
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder!.next
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        return nil
    }
}

extension UIView {
    func setCorder(radius: CGFloat) {
        self.layer.cornerRadius = radius
        self.clipsToBounds = true
    }
    
    func pressAnimation(_ completion: @escaping () -> Void) {
        UIDevice.haptic(.light)
        
        UIView.animate(withDuration: 0.1,
                       delay: 0,
                       options: [.curveEaseOut, .allowUserInteraction],
                       animations: { [weak self] in
            self?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1,
                           delay: 0,
                           options: [.curveEaseIn, .allowUserInteraction],
                           animations: { [weak self] in
                self?.transform = .identity
            }) { _ in
                completion()
            }
        }
    }
}

extension UIColor {
    
    convenience init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Remove '#' if present
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }
        
        var rgbValue: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgbValue)
        
        let r, g, b, a: CGFloat
        
        switch cleaned.count {
        case 6: // RRGGBB
            r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgbValue & 0x0000FF) / 255.0
            a = 1.0
            
        case 8: // RRGGBBAA
            r = CGFloat((rgbValue & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgbValue & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgbValue & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgbValue & 0x000000FF) / 255.0
            
        default:
            // Invalid hex → return gray
            r = 0.5; g = 0.5; b = 0.5; a = 1.0
        }
        
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

extension UIDevice {
    static func haptic(_ type: HapticFeedbackType) {
        switch type {
        case .selection:
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
            
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
            
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)
            
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
            
        case .light:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
            
        case .medium:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            
        case .heavy:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
        }
    }
}

extension UITextField {
    func setPlaceholder(_ text: String, color: UIColor = .lightGray, font: UIFont = .systemFont(ofSize: 15)) {
        self.attributedPlaceholder = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: color,
                .font: font
            ]
        )
    }
}
