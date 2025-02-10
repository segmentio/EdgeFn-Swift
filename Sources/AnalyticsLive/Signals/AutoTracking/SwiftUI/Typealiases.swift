//
//  File.swift
//  
//
//  Created by Brandon Sneed on 2/15/24.
//

import Foundation

// These aliases need to go into the containing app. They're included here
// simply as a placeholder and are not exported.


// Navigation
//typealias NavigationLink = SignalNavigationLink
//@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
//typealias NavigationStack = SignalNavigationStack

// Selection & Input Controls
typealias Button = SignalButton
typealias TextField = SignalTextField
typealias SecureField = SignalSecureField
typealias Picker = SignalPicker
typealias Toggle = SignalToggle
#if !os(tvOS)
typealias Slider = SignalSlider
typealias Stepper = SignalStepper
#endif

// List & Collection Views
typealias List = SignalList
typealias ScrollView = SignalScrollView
//@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
//typealias TabView = SignalTabView
