//
//  Storyboard+Extension.swift
//  iOS-Sumoti
//
//  Created by Kenil's MacMini on 05/12/23.
//

import Foundation
import UIKit

extension UIViewController {

    enum ControllerName: String {

        // Main
        case HistoryVC = "HistoryVC"
        
        // Others
        case PickVideoPopUp = "PickVideoPopUp"
        case LanguageBottomSheet = "LanguageBottomSheet"
        
        // Caption
        case SelectLanguageVC = "SelectLanguageVC"
        case CaptionVC = "CaptionVC"
        case GeneratingCaptionVC = "GeneratingCaptionVC"
        case EditCaptionStyleVC = "EditCaptionStyleVC"
        
        func storyboardName() -> StoryboardName {
            switch self {
            case .HistoryVC:
                return .Main
             
            case .PickVideoPopUp, .LanguageBottomSheet:
                return .Others
                
            case .SelectLanguageVC, .CaptionVC, .GeneratingCaptionVC, .EditCaptionStyleVC:
                return .Caption
            }
        }
        
    }

    enum StoryboardName: String {
        case Main = "Main"
        case Others = "Others"
        case Caption = "Caption"
        
        var instance: UIStoryboard {
            return UIStoryboard(name: self.rawValue, bundle: .main)
        }

        func viewController<T: UIViewController>(viewControllerClass: T.Type) -> T {
            let storyboardID = (viewControllerClass as UIViewController.Type).storyboardID
            return instance.instantiateViewController(withIdentifier: storyboardID) as! T
        }

        func initialViewController() -> UIViewController? {
            return instance.instantiateInitialViewController()
        }
    }

    class var storyboardID: String {
        return "\(self)"
    }

    static func instantiate() -> Self {
        let storyboardID = (self as UIViewController.Type).storyboardID
        let storyboard = ControllerName(rawValue: storyboardID)!.storyboardName()
        return storyboard.viewController(viewControllerClass: self)
    }

    func pushVC(vc: UIViewController, animation: Bool) {
        self.navigationController?.pushViewController(vc, animated: animation)
    }

    func setVC(vc: UIViewController, animation: Bool) {
        self.navigationController?.setViewControllers([vc], animated: animation)
    }

    func popVC(animated:Bool = true) {
        self.navigationController?.popViewController(animated: animated)
    }

    func popViewController(vcIndex : Int?, animated:Bool = true) {
        let array = navigationController?.viewControllers

        if let object = array?[vcIndex!] {
            navigationController?.popToViewController(object, animated: animated)
        }
    }
}

extension UINavigationController {
    func popToViewController(ofClass: AnyClass, animated: Bool = true) {
        if let vc = viewControllers.last(where: { $0.isKind(of: ofClass) }) {
            popToViewController(vc, animated: animated)
        }
    }
}
