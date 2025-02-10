//
//  SignalUIViewController.swift
//  AnalyticsLive
//
//  Created by Brandon Sneed on 2/7/25.
//

import UIKit
import ObjectiveC
import SwiftUI
import Segment

internal class ModalSwizzler {
    static let shared = ModalSwizzler()
    private var presentHandle: Swizzler.SwizzleHandle?
    private var dismissHandle: Swizzler.SwizzleHandle?
    @Atomic private var isRunning = false
    internal var currentModalName: String?
    
    func start() {
        if isRunning {
            return
        }
        _isRunning.set(true)
        
        // Present tracking
        let presentSelector = #selector(UIViewController.present(_:animated:completion:))
        presentHandle = Swizzler.swizzle(originalClass: UIViewController.self,
                                       originalSelector: presentSelector,
                                       swizzledSelector: #selector(UIViewController.swizzled_present(_:animated:completion:)))
        
        // Dismiss tracking
        let dismissSelector = #selector(UIViewController.dismiss(animated:completion:))
        dismissHandle = Swizzler.swizzle(originalClass: UIViewController.self,
                                        originalSelector: dismissSelector,
                                        swizzledSelector: #selector(UIViewController.swizzled_dismiss(animated:completion:)))
    }
    
    func stop() {
        if var handle = presentHandle {
            handle.restore()
        }
        if var handle = dismissHandle {
            handle.restore()
        }
        _isRunning.set(false)
    }
}

extension UIViewController {
    var meaningfulName: String {
        // Try all our previous methods first
        if let name = self.accessibilityLabel ?? self.title ?? self.navigationItem.title {
            return name
        }
        
        // If we're in a navigation controller, try to get its title
        if let nav = self as? UINavigationController,
           let topVC = nav.topViewController,
           let navTitle = topVC.accessibilityLabel ?? topVC.title ?? topVC.navigationItem.title {
            return navTitle
        }
        
        // If we have a navigation controller, try its top view controller
        if let nav = self.navigationController,
           let navTitle = nav.topViewController?.accessibilityLabel ??
            nav.topViewController?.title ??
            nav.topViewController?.navigationItem.title {
            return navTitle
        }
        
        // If we've got a hosting controller, try to get the SwiftUI view name
        if let hostingController = self as? UIHostingController<AnyView> {
            let mirror = Mirror(reflecting: hostingController.rootView)
            let value = String(describing: mirror.subjectType)
                .replacingOccurrences(of: "ModifiedContent<", with: "")
                .replacingOccurrences(of: ", RootModifier>", with: "")
                .replacingOccurrences(of: ", _TraitWritingModifier<.*>>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "AnyView", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty == false {
                return value
            }
        }
        
        // Clean up the type name if we have to use it
        return String(describing: type(of: self))
    }
    
    @objc dynamic func swizzled_present(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
        let modalScreen = viewControllerToPresent.meaningfulName
        
        // Call original implementation
        self.swizzled_present(viewControllerToPresent, animated: animated, completion: completion)
        
        // Just emit the modal signal and save the name
        let modalSignal = NavigationSignal(action: .modal, screen: modalScreen)
        Signals.emit(signal: modalSignal, source: .autoSwiftUI)
        ModalSwizzler.shared.currentModalName = modalScreen
    }
    
    @objc dynamic func swizzled_dismiss(animated: Bool, completion: (() -> Void)? = nil) {
        // Get the saved modal name
        let modalScreen = ModalSwizzler.shared.currentModalName ?? self.meaningfulName
        
        // Call original implementation
        self.swizzled_dismiss(animated: animated, completion: completion)
        
        // Just emit leaving for the modal
        let leavingSignal = NavigationSignal(action: .leaving, screen: modalScreen)
        Signals.emit(signal: leavingSignal, source: .autoSwiftUI)
        
        // Clear the saved name
        ModalSwizzler.shared.currentModalName = nil
    }
}
