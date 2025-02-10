//
//  SignalScrollView.swift
//  AnalyticsLive
//
//  Created by Brandon Sneed on 2/5/25.
//

import SwiftUI

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct SignalScrollView<Content>: SignalingUI, View where Content: View {
    private let axes: Axis.Set
    private let showsIndicators: Bool
    private let content: () -> Content
    private let signalLabel: Any?
    
    // State for tracking scroll position
    @State private var lastEmittedPosition: CGPoint = .zero
    @State private var lastEmissionTime: Date = .distantPast
    @State private var edgeState: Set<Edge> = []
    
    public var body: some View {
        SwiftUI.ScrollView(axes, showsIndicators: showsIndicators) {
            content()
                .background(
                    ScrollDetector { position, bounds, contentSize in
                        let now = Date()
                        // Debounce to prevent signal spam (100ms minimum between signals)
                        guard now.timeIntervalSince(lastEmissionTime) > 0.1 else { return }
                        
                        // Calculate deltas
                        let deltaX = position.x - lastEmittedPosition.x
                        let deltaY = position.y - lastEmittedPosition.y
                        
                        // Check for significant movement (20pt threshold)
                        let significantChangeX = abs(deltaX) > 20
                        let significantChangeY = abs(deltaY) > 20
                        
                        guard significantChangeX || significantChangeY else { return }
                        
                        // Determine primary scroll direction based on larger delta
                        let direction: String
                        if abs(deltaX) > abs(deltaY) {
                            direction = deltaX > 0 ? "right" : "left"
                        } else {
                            direction = deltaY > 0 ? "down" : "up"
                        }
                        
                        // Check edges
                        var currentEdges = Set<Edge>()
                        
                        // Left edge
                        if position.x <= 0 {
                            currentEdges.insert(.leading)
                        }
                        // Right edge
                        if position.x + bounds.width >= contentSize.width {
                            currentEdges.insert(.trailing)
                        }
                        // Top edge
                        if position.y <= 0 {
                            currentEdges.insert(.top)
                        }
                        // Bottom edge
                        if position.y + bounds.height >= contentSize.height {
                            currentEdges.insert(.bottom)
                        }
                        
                        // Only emit edge signals if we've hit a new edge
                        let newEdges = currentEdges.subtracting(edgeState)
                        if !newEdges.isEmpty {
                            for edge in newEdges {
                                let edgeSignal = InteractionSignal(
                                    component: Self.controlType(),
                                    title: nil,
                                    data: [
                                        "action": "scrollEdge",
                                        "edge": edge.description
                                    ]
                                )
                                Signals.emit(signal: edgeSignal, source: .autoSwiftUI)
                            }
                        }
                        
                        // Emit scroll signal
                        let signal = InteractionSignal(
                            component: Self.controlType(),
                            title: nil,
                            data: [
                                "action": "scroll",
                                "direction": direction,
                                "deltaX": deltaX,
                                "deltaY": deltaY,
                                "atEdges": currentEdges.map { $0.description }
                            ]
                        )
                        Signals.emit(signal: signal, source: .autoSwiftUI)
                        
                        lastEmittedPosition = position
                        lastEmissionTime = now
                        edgeState = currentEdges
                    }
                )
        }
    }
    
    @inline(__always)
    static public func controlType() -> String {
        return "ScrollView"
    }
}

// MARK: - Edge Extension
internal extension Edge {
    var description: String {
        switch self {
        case .top: return "top"
        case .leading: return "leading"
        case .bottom: return "bottom"
        case .trailing: return "trailing"
        }
    }
}

// MARK: - ScrollDetector Helper View
internal struct ScrollDetector: UIViewRepresentable {
    let onScroll: (CGPoint, CGRect, CGSize) -> Void
    
    func makeUIView(context: Context) -> ScrollDetectionView {
        let view = ScrollDetectionView()
        view.onScroll = onScroll
        return view
    }
    
    func updateUIView(_ uiView: ScrollDetectionView, context: Context) {
        uiView.onScroll = onScroll
    }
}

// MARK: - ScrollDetectionView
internal class ScrollDetectionView: UIView {
    var onScroll: ((CGPoint, CGRect, CGSize) -> Void)?
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        // Find the UIScrollView
        var superview = self.superview
        while let view = superview, !view.isKind(of: UIScrollView.self) {
            superview = view.superview
        }
        
        guard let scrollView = superview as? UIScrollView else { return }
        
        // Add scroll observation
        scrollView.addObserver(self, forKeyPath: #keyPath(UIScrollView.contentOffset), options: [.new, .old], context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(UIScrollView.contentOffset) {
            if let scrollView = object as? UIScrollView {
                onScroll?(
                    scrollView.contentOffset,
                    scrollView.bounds,
                    scrollView.contentSize
                )
            }
        }
    }
    
    deinit {
        // Find and remove scroll observation
        var superview = self.superview
        while let view = superview, !view.isKind(of: UIScrollView.self) {
            superview = view.superview
        }
        
        if let scrollView = superview as? UIScrollView {
            scrollView.removeObserver(self, forKeyPath: #keyPath(UIScrollView.contentOffset))
        }
    }
}

// MARK: - Initializers
extension SignalScrollView {
    // Base initializer
    public init(_ axes: Axis.Set = .vertical, showsIndicators: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.content = content
        self.signalLabel = nil
    }
    
    // iOS 16.0+ / macOS 13.0+ initializer with ScrollIndicatorVisibility
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public init(_ axes: Axis.Set = .vertical, showsIndicators: ScrollIndicatorVisibility, @ViewBuilder content: @escaping () -> Content) {
        self.axes = axes
        // Map ScrollIndicatorVisibility to bool
        switch showsIndicators {
        case .automatic, .visible:
            self.showsIndicators = true
        case .hidden:
            self.showsIndicators = false
        default:
            self.showsIndicators = true
        }
        self.content = content
        self.signalLabel = nil
    }
}

// MARK: - Coordinate Space Initializers
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension SignalScrollView where Content == AnyView {
    // iOS 14.0+ / macOS 11.0+ initializer with coordinateSpace name
    public init<V: View>(_ axes: Axis.Set = .vertical, showsIndicators: Bool = true, coordinateSpace: String, @ViewBuilder content: @escaping () -> V) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.content = { AnyView(content().coordinateSpace(name: coordinateSpace)) }
        self.signalLabel = nil
    }
    
    // iOS 16.0+ / macOS 13.0+ initializer with both ScrollIndicatorVisibility and coordinateSpace
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public init<V: View>(_ axes: Axis.Set = .vertical, showsIndicators: ScrollIndicatorVisibility, coordinateSpace: String, @ViewBuilder content: @escaping () -> V) {
        self.axes = axes
        // Map ScrollIndicatorVisibility to bool
        switch showsIndicators {
        case .automatic, .visible:
            self.showsIndicators = true
        case .hidden:
            self.showsIndicators = false
        default:
            self.showsIndicators = true
        }
        self.content = { AnyView(content().coordinateSpace(name: coordinateSpace)) }
        self.signalLabel = nil
    }
}
