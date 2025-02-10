//
//  SignalTabView.swift
//  AnalyticsLive
//
//  Created by Brandon Sneed on 2/5/25.
//

import SwiftUI

extension Binding {
    public func onUpdate(_ closure: @escaping (_ newValue: Value, _ oldValue: Value) -> Void) -> Binding<Value> {
        Binding(get: {
            wrappedValue
        }, set: { newValue in
            let oldValue = wrappedValue
            wrappedValue = newValue
            closure(newValue, oldValue)
        })
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 7.0, *)
public struct SignalTabView<SelectionValue, Content> : SignalingUI, View
    where SelectionValue : Hashable, Content : View
{
    internal let lifecycle: TabViewLifecycle
    @State private var selectedTab: Int = 0
    private let id = UUID()
    private let userDefinedSelection: Binding<SelectionValue>?
    
    private let content: Any
    
    @available(iOS, deprecated: 100000.0, message: "Use TabContentBuilder-based TabView initializers instead")
    @available(macOS, deprecated: 100000.0, message: "Use TabContentBuilder-based TabView initializers instead")
    @available(tvOS, deprecated: 100000.0, message: "Use TabContentBuilder-based TabView initializers instead")
    @available(watchOS, deprecated: 100000.0, message: "Use TabContentBuilder-based TabView initializers instead")
    public init(selection: Binding<SelectionValue>?, @ViewBuilder content: () -> Content) {
        self.lifecycle = TabViewLifecycle(id: id) // this has to come first
        self.content = content()
        self.userDefinedSelection = selection
    }

    /// Creates a tab view that uses a builder to create and specify
    /// selection values for its tabs.
    ///
    /// - Parameters:
    ///     - selection: The selection in the TabView. The value of this
    ///         binding must match the `value` of the tabs in `content`.
    ///     - content: The ``Tab`` content.
    @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    public init<C>(selection: Binding<SelectionValue>, @TabContentBuilder<SelectionValue> content: () -> C) where Content == TabContentBuilder<SelectionValue>.Content<C>, C : TabContent {
        self.lifecycle = TabViewLifecycle(id: id) // this has to come first
        self.content = content() as! TabContentBuilder<SelectionValue>.Content<C>
        self.userDefinedSelection = selection
    }

    public var body: some View {
        if let userDefinedSelection {
            SwiftUI.TabView(selection: userDefinedSelection.onUpdate { newValue, oldValue in
                if newValue is Encodable, oldValue is Encodable {
                    let signal = InteractionSignal(
                        component: Self.controlType(),
                        title: nil,
                        data: [
                            "action": "tabSelected",
                            "previousTab": oldValue,
                            "selectedTab": newValue,
                        ]
                    )
                    Signals.emit(signal: signal, source: .autoSwiftUI)
                }
            }) {
                content as! Content
            }
        } else {
            SwiftUI.TabView(selection: $selectedTab.onUpdate { newValue, oldValue in
                if let labels = SignalTabCache.getLabels(for: id) {
                    let signal = InteractionSignal(
                        component: Self.controlType(),
                        title: nil,
                        data: [
                            "action": "tabSelected",
                            "previousTab": labels[oldValue],
                            "selectedTab": labels[newValue],
                        ]
                    )
                    Signals.emit(signal: signal, source: .autoSwiftUI)
                }
            }) {
                content as! Content
            }
        }
    }
    
    @inline(__always)
    static public func controlType() -> String {
        return "TabView"
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 7.0, *)
extension SignalTabView where SelectionValue == Int {
    nonisolated public init(@ViewBuilder content: () -> Content) {
        self.lifecycle = TabViewLifecycle(id: id) // this has to come first
        self.content = content()
        self.userDefinedSelection = nil
    }
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
extension SignalTabView {
    public init<C>(@TabContentBuilder<Never> content: () -> C)
    where SelectionValue == Never, Content == TabContentBuilder<Never>.Content<C>, C : TabContent
    {
        self.lifecycle = TabViewLifecycle(id: id) // this has to come first
        self.content = content()
        self.userDefinedSelection = nil
    }
}

internal final class TabViewLifecycle {
    let id: UUID
    
    init(id: UUID) {
        self.id = id
        SignalTabCache.push(id)
    }
    
    deinit {
        SignalTabCache.pop(id)
    }
}

// Cache using UUID instead of View
internal struct SignalTabCache {
    static var tabViews = [UUID: [String]]()
    static var ids = [UUID]()
    
    static func push(_ id: UUID) {
        if let existingLabels = tabViews[id] {
            return
        } else {
            tabViews[id] = []
            ids.append(id)
        }
    }
    
    static func pop(_ id: UUID) {
        tabViews.removeValue(forKey: id)
        if let index = ids.firstIndex(of: id) {
            ids.remove(at: index)
        }
    }
    
    static func addLabel(_ label: String) {
        if let id = ids.last {
            if tabViews[id] == nil {
                tabViews[id] = [label]
            } else {
                tabViews[id]?.append(label)
            }
        }
    }
    
    static func getLabels(for id: UUID) -> [String]? {
        let result = tabViews[id]
        if result?.count == 0 { return nil }
        return result
    }
}

// MARK: - View Extension
extension View {
    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
        public func signalTabItem<V: View>(@ViewBuilder _ label: @escaping () -> V) -> some View {
            let lbl = SignalTabView<AnyHashable, AnyView>.extractLabel(label())
            SignalTabCache.addLabel(lbl)
            return self.tabItem(label)
        }
}
