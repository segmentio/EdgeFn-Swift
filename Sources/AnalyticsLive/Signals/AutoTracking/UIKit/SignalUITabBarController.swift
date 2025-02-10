//
//  SignalUITabBarController.swift
//  AnalyticsLive
//
//  Created by Brandon Sneed on 2/7/25.
//

#if canImport(UIKit) && !os(watchOS)

import UIKit
import ObjectiveC
import Segment

internal class TabBarSwizzler {
    static let shared = TabBarSwizzler()
    private var handle: Swizzler.SwizzleHandle?
    @Atomic private var isRunning = false
    
    func start() {
        if isRunning {
            return
        }
        _isRunning.set(true)
        
        let selector = Selector(("_setSelectedViewController:"))
        handle = Swizzler.swizzle(originalClass: UITabBarController.self,
                                 originalSelector: selector,
                                 swizzledSelector: #selector(UITabBarController.swizzled_setSelectedViewController(_:)))
    }
    
    func stop() {
        if var handle = handle {
            handle.restore()
        }
        _isRunning.set(false)
    }
}

extension UITabBarController {
    @objc dynamic func swizzled_setSelectedViewController(_ viewController: UIViewController?) {
        // Get index before we call original
        var oldIndex = selectedIndex
        // on the first time through, it's some giant value, i assume it's uninitialized.
        // so ... if it's over 100, we'll assume we're there.  who'd have 100 tabs???
        if oldIndex > 100 { oldIndex = 0 }
        let newIndex = viewControllers?.firstIndex(of: viewController ?? UIViewController()) ?? NSNotFound
        
        // Call original implementation
        self.swizzled_setSelectedViewController(viewController)
        
        // Only emit if we have a valid index change
        if newIndex != NSNotFound && newIndex != oldIndex {
            var data: [String: Any] = [
                "action": "tabSelected",
                "previousTab": oldIndex,
                "selectedTab": newIndex
            ]
            
            // Try to get tab names if available
            if let items = tabBar.items {
                if newIndex < items.count {
                    let newItem = items[newIndex]
                    if let description = newItem.accessibilityLabel {
                        data["selectedTabName"] = description
                    } else if let title = newItem.title {
                        data["selectedTabName"] = title
                    }
                }
                
                if oldIndex < items.count {
                    let oldItem = items[oldIndex]
                    if let description = oldItem.accessibilityLabel {
                        data["previousTabName"] = description
                    } else if let title = oldItem.title {
                        data["previousTabName"] = title
                    }
                }
            }
            
            let signal = InteractionSignal(
                component: "TabView",
                title: nil,
                data: data
            )
            Signals.emit(signal: signal, source: .autoSwiftUI)
        }
    }
}

#else

internal class TabBarSwizzler {
    static let shared = TabBarSwizzler()
    @Atomic private var isRunning = false
    
    func start() {
        if isRunning {
            return
        }
        _isRunning.set(true)
        
        // TODO: Implement AppKit tab tracking when needed
        // Will likely use NSTabViewController or similar
    }
    
    func stop() {
        _isRunning.set(false)
    }
}


#endif
