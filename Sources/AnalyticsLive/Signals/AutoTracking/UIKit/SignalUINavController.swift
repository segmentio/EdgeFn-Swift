//
//  SignalUINavController.swift
//  AnalyticsLive
//
//  Created by Brandon Sneed on 2/7/25.
//

#if canImport(UIKit) && !os(watchOS)

import UIKit
import ObjectiveC
import Segment

internal class NavigationSwizzler {
    static let shared = NavigationSwizzler()
    private var pushHandle: Swizzler.SwizzleHandle?
    private var popHandle: Swizzler.SwizzleHandle?
    private var popToVCHandle: Swizzler.SwizzleHandle?
    private var popToRootHandle: Swizzler.SwizzleHandle?
    @Atomic private var isRunning = false
    
    func start() {
        if isRunning {
            return
        }
        _isRunning.set(true)
        
        // Push tracking
        let pushSelector = #selector(UINavigationController.pushViewController(_:animated:))
        pushHandle = Swizzler.swizzle(originalClass: UINavigationController.self,
                                      originalSelector: pushSelector,
                                      swizzledSelector: #selector(UINavigationController.swizzled_pushViewController(_:animated:)))
        
        // Pop tracking
        let popSelector = #selector(UINavigationController.popViewController(animated:))
        popHandle = Swizzler.swizzle(originalClass: UINavigationController.self,
                                     originalSelector: popSelector,
                                     swizzledSelector: #selector(UINavigationController.swizzled_popViewController(animated:)))
        
        // Pop to specific VC tracking
        let popToVCSelector = #selector(UINavigationController.popToViewController(_:animated:))
        popToVCHandle = Swizzler.swizzle(originalClass: UINavigationController.self,
                                        originalSelector: popToVCSelector,
                                        swizzledSelector: #selector(UINavigationController.swizzled_popToViewController(_:animated:)))
        // Pop to root tracking
        let popToRootSelector = #selector(UINavigationController.popToRootViewController(animated:))
        popToRootHandle = Swizzler.swizzle(originalClass: UINavigationController.self,
                                          originalSelector: popToRootSelector,
                                          swizzledSelector: #selector(UINavigationController.swizzled_popToRootViewController(animated:)))
    }
    
    func stop() {
        if var handle = pushHandle {
            handle.restore()
        }
        if var handle = popHandle {
            handle.restore()
        }
        if var handle = popToRootHandle {
            handle.restore()
        }
        if var handle = popToVCHandle {
            handle.restore()
        }
        _isRunning.set(false)
    }
}

extension UINavigationController {
    @objc dynamic func swizzled_pushViewController(_ viewController: UIViewController, animated: Bool) {
        // Get info before we push
        let fromVC = topViewController
        
        // Call original implementation
        self.swizzled_pushViewController(viewController, animated: animated)
        
        // Emit 'leaving' signal for the screen we're leaving
        if let fromScreen = fromVC?.accessibilityLabel ?? fromVC?.title ?? fromVC?.navigationItem.title {
            let leavingSignal = NavigationSignal(action: .leaving, screen: fromScreen)
            Signals.emit(signal: leavingSignal, source: .autoSwiftUI)
        }
        
        // Emit 'entering' signal for the screen we're pushing to
        if let toScreen = viewController.accessibilityLabel ?? viewController.title ?? viewController.navigationItem.title {
            let enteringSignal = NavigationSignal(action: .entering, screen: toScreen)
            Signals.emit(signal: enteringSignal, source: .autoSwiftUI)
        }
    }

    @objc dynamic func swizzled_popViewController(animated: Bool) -> UIViewController? {
        // Get info before we pop
        let fromVC = topViewController
        let toVC = viewControllers.count > 1 ? viewControllers[viewControllers.count - 2] : nil
        
        // Call original implementation
        let result = self.swizzled_popViewController(animated: animated)
        
        // Emit 'leaving' signal for the screen we're popping from
        if let fromScreen = fromVC?.accessibilityLabel ?? fromVC?.title ?? fromVC?.navigationItem.title {
            let leavingSignal = NavigationSignal(action: .leaving, screen: fromScreen)
            Signals.emit(signal: leavingSignal, source: .autoSwiftUI)
        }
        
        // Emit 'entering' signal for the screen we're popping back to
        if let toScreen = toVC?.accessibilityLabel ?? toVC?.title ?? toVC?.navigationItem.title {
            let enteringSignal = NavigationSignal(action: .entering, screen: toScreen)
            Signals.emit(signal: enteringSignal, source: .autoSwiftUI)
        }
        
        return result
    }

    @objc dynamic func swizzled_popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
        // Get info before we pop
        let fromVC = topViewController
        
        // Call original implementation
        let result = self.swizzled_popToViewController(viewController, animated: animated)
        
        // Emit 'leaving' signal for current screen
        if let fromScreen = fromVC?.accessibilityLabel ?? fromVC?.title ?? fromVC?.navigationItem.title {
            let leavingSignal = NavigationSignal(action: .leaving, screen: fromScreen)
            Signals.emit(signal: leavingSignal, source: .autoSwiftUI)
        }
        
        // Emit 'entering' signal for target screen
        if let toScreen = viewController.accessibilityLabel ?? viewController.title ?? viewController.navigationItem.title {
            let enteringSignal = NavigationSignal(action: .entering, screen: toScreen)
            Signals.emit(signal: enteringSignal, source: .autoSwiftUI)
        }
        
        return result
    }

    
    @objc dynamic func swizzled_popToRootViewController(animated: Bool) -> [UIViewController]? {
        // Get info before we pop
        let fromVC = topViewController
        let rootVC = viewControllers.first
        let depth = viewControllers.count - 1 // How many VCs we're popping
        
        // Call original implementation
        let result = self.swizzled_popToRootViewController(animated: animated)
        
        // Emit 'leaving' signal for current screen
        if let fromScreen = fromVC?.accessibilityLabel ?? fromVC?.title ?? fromVC?.navigationItem.title {
            let leavingSignal = NavigationSignal(action: .leaving, screen: fromScreen)
            Signals.emit(signal: leavingSignal, source: .autoSwiftUI)
        }
        
        // Emit 'entering' signal for target screen
        if let toScreen = rootVC?.accessibilityLabel ?? rootVC?.title ?? rootVC?.navigationItem.title {
            let enteringSignal = NavigationSignal(action: .entering, screen: toScreen)
            Signals.emit(signal: enteringSignal, source: .autoSwiftUI)
        }
        
        return result
    }
}

#else

internal class NavigationSwizzler {
    static let shared = NavigationSwizzler()
    @Atomic private var isRunning = false
    
    func start() {
        if isRunning {
            return
        }
        _isRunning.set(true)
        
        // TODO: Implement AppKit navigation tracking when needed
        // Will likely use NSSplitViewController or similar
    }
    
    func stop() {
        _isRunning.set(false)
    }
}

#endif
