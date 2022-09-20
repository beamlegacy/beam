//
//  SwiftUIEnvironmentKeys.swift
//  Beam
//
//  Created by Remi Santos on 14/09/2022.
//

import SwiftUI


// MARK: - Main Window environment value
private struct IsMainWindowEnvironmentKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var isMainWindow: Bool {
        get { self[IsMainWindowEnvironmentKey.self] }
        set { self[IsMainWindowEnvironmentKey.self] = newValue }
    }
}

// MARK: - Window Frame environment value
private struct WindowFrameEnvironmentKey: EnvironmentKey {
    static let defaultValue = CGRect.zero
}
private struct IsCompactContentViewEnvironmentKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var windowFrame: CGRect {
        get { self[WindowFrameEnvironmentKey.self] }
        set { self[WindowFrameEnvironmentKey.self] = newValue }
    }

    var isCompactContentView: Bool {
        get { self[IsCompactContentViewEnvironmentKey.self] }
        set { self[IsCompactContentViewEnvironmentKey.self] = newValue }
    }
}

// MARK: - Window Help

// The reason we use a struct to wrap the action (like Apple does with its own types)
// is because of performance issues when passing functions directly into the environment.
// https://twitter.com/lukeredpath/status/1491127803328495618
struct HelpAction {
    let action: () -> Void
    init(_ action: @escaping () -> Void) {
        self.action = action
    }
    func callAsFunction() {
        action()
    }
}

private struct ShowHelpActionEnvironmentKey: EnvironmentKey {
    static let defaultValue = HelpAction({ })
}
extension EnvironmentValues {
    var showHelpAction: HelpAction {
        get { self[ShowHelpActionEnvironmentKey.self] }
        set { self[ShowHelpActionEnvironmentKey.self] = newValue }
    }
}

// MARK: - Favicon Provider environment value
private struct FaviconProviderEnvironmentKey: EnvironmentKey {
    static let defaultValue = FaviconProvider(withCache: FaviconCache(countLimit: 1))
}
extension EnvironmentValues {
    var faviconProvider: FaviconProvider {
        get { self[FaviconProviderEnvironmentKey.self] }
        set { self[FaviconProviderEnvironmentKey.self] = newValue }
    }
}
extension View {
    func faviconProvider(_ provider: FaviconProvider) -> some View {
        self.environment(\.faviconProvider, provider)
    }
}
