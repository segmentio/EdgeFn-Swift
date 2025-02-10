//
//  SignalList.swift
//  AnalyticsLive
//
//  Created by Brandon Sneed on 2/5/25.
//

import SwiftUI

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct SignalList<SelectionValue, Content>: SignalingUI, View
    where SelectionValue: Hashable, Content: View {
    
    let sui: SwiftUI.List<SelectionValue, Content>
    let signalSelection: Binding<Set<SelectionValue>>?
    @State private var lastSelection: Set<SelectionValue> = []
    
    public var body: some View {
        Group {
            if #available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *) {
                if let selection = signalSelection {
                    sui.onChange(of: selection.wrappedValue) { newValue in
                        let action: String
                        let items: [String]
                        
                        if newValue.isEmpty && !lastSelection.isEmpty {
                            action = "selection_ended"
                            items = Array(lastSelection).map { String(describing: $0) }
                        } else {
                            action = newValue.count > lastSelection.count ? "item_selected" : "item_deselected"
                            items = Array(newValue).map { String(describing: $0) }
                        }
                        
                        let signal = InteractionSignal(
                            component: Self.controlType(),
                            title: nil,
                            data: [
                                "action": action,
                                "selectedCount": items.count,
                                "selectedItems": items
                            ]
                        )
                        Signals.emit(signal: signal, source: .autoSwiftUI)
                        lastSelection = newValue
                    }
                } else {
                    sui
                }
            } else {
                sui
            }
        }
    }
    
    @inline(__always)
    static public func controlType() -> String {
        return "List"
    }
}

// MARK: - Basic Initializers
extension SignalList {
    public init(selection: Binding<Set<SelectionValue>>? = nil, @ViewBuilder content: () -> Content) {
        self.sui = SwiftUI.List(selection: selection, content: content)
        self.signalSelection = selection
    }
}
