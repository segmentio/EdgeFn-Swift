//
//  SignalUIApplication.swift
//  AnalyticsLive
//
//  Created by Brandon Sneed on 2/10/25.
//

#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)

import Foundation
import UIKit
import Segment

internal class TapSwizzler {
    static let shared = TapSwizzler()
    private var handle: Swizzler.SwizzleHandle?
    @Atomic private var isRunning = false
    
    func start() {
        if isRunning {
            return
        }
        _isRunning.set(true)
        
        let selector = #selector(UIApplication.sendEvent(_:))
        handle = Swizzler.swizzle(originalClass: UIApplication.self,
                                 originalSelector: selector,
                                 swizzledSelector: #selector(UIApplication.swizzled_sendEvent(_:)))
    }
    
    func stop() {
        if var handle = handle {
            handle.restore()
        }
        _isRunning.set(false)
    }
}

extension UIApplication {
    private func getKeyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .map({ $0 as? UIWindowScene })
            .compactMap({ $0 })
            .first?.windows
            .filter({ $0.isKeyWindow }).first
    }
    
    @objc dynamic func swizzled_sendEvent(_ event: UIEvent) {
        if let window = self.getKeyWindow(),
           let touch = event.touches(for: window)?.first {
            let control = touch.view?.className ?? "Unknown"
            var title: String?
            var data: [String: Any]?
            
            switch touch.view {
            case let v as UIButton:
                title = v.accessibilityLabel ?? v.currentTitle
            case let v as UISlider:
                title = v.accessibilityLabel
                data = ["value": v.value]
            case let v as UIStepper:
                title = v.accessibilityLabel
                data = ["value": v.value]
            case let v as UISwitch:
                title = v.accessibilityLabel
                data = ["value": v.isOn]
            case let v as UITextField:
                title = v.accessibilityLabel ?? v.placeholder
                let text = v.isSecureTextEntry ? "" : (v.text ?? "")
                data = ["value": text, "secure": v.isSecureTextEntry]
            case let v as UITableViewCell:
                title = extractTableCellTitle(from: v)
                data = [
                    "isSelected": v.isSelected,
                    "isHighlighted": v.isHighlighted,
                    "isEditing": v.isEditing,
                    "showingDeleteConfirmation": v.showingDeleteConfirmation
                ]
            default:
                title = touch.view?.accessibilityIdentifier
            }
            
            Signals.emit(signal: InteractionSignal(component: control, title: title, data: data),
                        source: .autoUIKit)
        }
        
        // Call original implementation
        self.swizzled_sendEvent(event)
    }
    
    private func extractTableCellTitle(from cell: UITableViewCell) -> String? {
        // Find topmost label
        var highestY: CGFloat = -1
        var topmostTitle: String?
        
        for subview in cell.subviews {
            if let label = subview as? UILabel,
               label.frame.origin.y > highestY {
                highestY = label.frame.origin.y
                topmostTitle = label.accessibilityLabel ?? label.text
            }
        }
        
        // Fallback to standard properties if needed
        return topmostTitle ?? cell.accessibilityLabel ?? cell.textLabel?.text
    }
}

extension NSObject {
    var className: String {
        return NSStringFromClass(type(of: self))
    }
}

#else

import Foundation
import AppKit

internal class TapSwizzler {
    static let shared = TapSwizzler()
    @Atomic private var isRunning = false
    
    func start() {
        if isRunning {
            return
        }
        _isRunning.set(true)
        
        // TODO: handle appkit stuff at some point
    }
    
    func stop() {
        _isRunning.set(false)
    }
}

#endif
