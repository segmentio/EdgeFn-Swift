//
//  Swizzler.swift
//  AnalyticsLive
//
//  Created by Brandon Sneed on 2/7/25.
//

import UIKit
import ObjectiveC

/// Utility for safely swizzling methods
internal final class Swizzler {
    /// Represents a single swizzled method
    struct SwizzleHandle {
        let originalClass: AnyClass
        let originalSelector: Selector
        let swizzledSelector: Selector
        private(set) var isActive: Bool = true
        
        // Store original and swizzled methods for restoration
        private let originalMethod: Method
        private let swizzledMethod: Method
        
        fileprivate init(originalClass: AnyClass, originalSelector: Selector, swizzledSelector: Selector,
                        originalMethod: Method, swizzledMethod: Method) {
            self.originalClass = originalClass
            self.originalSelector = originalSelector
            self.swizzledSelector = swizzledSelector
            self.originalMethod = originalMethod
            self.swizzledMethod = swizzledMethod
        }
        
        /// Safely restore the original method
        mutating func restore() {
            guard isActive else { return }
            objc_synchronized(originalClass) {
                method_exchangeImplementations(swizzledMethod, originalMethod)
                isActive = false
            }
        }
    }
    
    /// Thread-safe storage of active swizzles
    private static let lock = NSLock()
    private static var activeSwizzles: [ObjectIdentifier: [Selector: SwizzleHandle]] = [:]
    
    /// Safely swizzle a method
    /// - Parameters:
    ///   - originalClass: The class containing the method to swizzle
    ///   - originalSelector: The original method selector
    ///   - swizzledSelector: The replacement method selector
    /// - Returns: A handle for managing the swizzled method
    @discardableResult
    static func swizzle(originalClass: AnyClass,
                       originalSelector: Selector,
                       swizzledSelector: Selector) -> SwizzleHandle? {
        // Get methods (thread-safe)
        guard let originalMethod = class_getInstanceMethod(originalClass, originalSelector),
              let swizzledMethod = class_getInstanceMethod(originalClass, swizzledSelector) else {
            // Failed to find methods for swizzling: \(originalSelector) -> \(swizzledSelector)
            return nil
        }
        
        let classKey = ObjectIdentifier(originalClass)
        
        return lock.synchronized {
            // Check if already swizzled
            if let existing = activeSwizzles[classKey]?[originalSelector] {
                // Method already swizzled: \(originalSelector)
                return existing
            }
            
            // Attempt to add the method if it doesn't exist
            let didAdd = class_addMethod(originalClass,
                                       originalSelector,
                                       method_getImplementation(swizzledMethod),
                                       method_getTypeEncoding(swizzledMethod))
            
            objc_synchronized(originalClass) {
                if didAdd {
                    // If we added it, just replace the implementation
                    class_replaceMethod(originalClass,
                                      swizzledSelector,
                                      method_getImplementation(originalMethod),
                                      method_getTypeEncoding(originalMethod))
                } else {
                    // Otherwise swap implementations
                    method_exchangeImplementations(originalMethod, swizzledMethod)
                }
            }
            
            // Create and store handle
            let handle = SwizzleHandle(originalClass: originalClass,
                                     originalSelector: originalSelector,
                                     swizzledSelector: swizzledSelector,
                                     originalMethod: originalMethod,
                                     swizzledMethod: swizzledMethod)
            
            // Store in active swizzles
            if activeSwizzles[classKey] == nil {
                activeSwizzles[classKey] = [:]
            }
            activeSwizzles[classKey]?[originalSelector] = handle
            
            // Successfully swizzled: \(originalSelector) -> \(swizzledSelector)
            return handle
        }
    }
    
    /// Restore all swizzled methods for a class
    static func restoreAll(for originalClass: AnyClass) {
        let classKey = ObjectIdentifier(originalClass)
        lock.synchronized {
            activeSwizzles[classKey]?.values.forEach { handle in
                var mutableHandle = handle
                mutableHandle.restore()
            }
            activeSwizzles.removeValue(forKey: classKey)
        }
    }
}

// MARK: - Helper Extensions

extension NSLock {
    internal func synchronized<T>(_ block: () -> T) -> T {
        lock()
        defer { unlock() }
        return block()
    }
}

internal func objc_synchronized<T>(_ object: AnyObject, block: () -> T) -> T {
    objc_sync_enter(object)
    defer { objc_sync_exit(object) }
    return block()
}
