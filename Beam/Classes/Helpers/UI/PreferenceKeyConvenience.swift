//
//  PreferenceKeyConvenience.swift
//  Beam
//
//  Created by Remi Santos on 18/07/2022.
//

import SwiftUI

/// Convenient protocol to declare a PreferenceKey containing a frame (CGRect).
///
/// All you need to do to have a local key to use in your SwiftUI View is to create a new struct with that protocol.
/// Exemple:
/// ```
///  struct LeadingButtonFramePrefKey: FramePreferenceKey {}
/// ```
/// Client can still provide a difference default value.
protocol FramePreferenceKey: PreferenceKey { }
extension FramePreferenceKey {
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = nextValue() ?? value
    }
}

/// Convenient protocol to declare a PreferenceKey containing a float value (CGFloat).
///
/// All you need to do to have a local key to use in your SwiftUI View is to create a new struct with that protocol.
/// Exemple:
/// ```
///  struct LeadingButtonHeightPrefKey: FramePreferenceKey {}
/// ```
/// Client can still provide a difference default value.
protocol FloatPreferenceKey: PreferenceKey { }
extension FloatPreferenceKey {
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}
