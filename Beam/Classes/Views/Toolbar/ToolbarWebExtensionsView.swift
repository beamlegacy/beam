//
//  ToolbarWebExtensionsView.swift
//  Beam
//

import SwiftUI
import WebKit

/// Toolbar buttons for the actions of the loaded web extensions.
@available(macOS 15.4, *)
struct ToolbarWebExtensionsView: View {
    @ObservedObject private var manager = WebExtensionsManager.shared
    @ObservedObject var tabsManager: BrowserTabsManager
    var isIncognito: Bool

    var body: some View {
        HStack(alignment: .center, spacing: BeamSpacing._40) {
            ForEach(manager.installedExtensions) { installed in
                if let context = installed.context, !isIncognito || context.hasAccessToPrivateData {
                    ToolbarWebExtensionButton(context: context, tab: tabsManager.currentTab, revision: manager.actionsRevision)
                }
            }
        }
    }
}

@available(macOS 15.4, *)
private struct ToolbarWebExtensionButton: View {
    @Environment(\.isMainWindow) private var isMainWindow: Bool

    let context: WKWebExtensionContext
    let tab: BrowserTab?
    /// Changes when an extension action is updated, to refresh icon and badge.
    let revision: Int

    @State private var anchorView: NSView?
    @State private var isHovering = false
    @State private var isTouchDown = false

    private static let iconSize = CGSize(width: 16, height: 16)

    private var name: String {
        context.webExtension.displayName ?? "Extension"
    }

    var body: some View {
        let action = context.action(for: tab)
        let icon = action?.icon(for: Self.iconSize) ?? context.webExtension.icon(for: Self.iconSize)
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let icon = icon {
                    Image(nsImage: icon).resizable()
                } else {
                    Image(systemName: "puzzlepiece.extension")
                        .resizable()
                        .foregroundColor(BeamColor.ToolBar.buttonForeground.swiftUI)
                }
            }
            .frame(width: Self.iconSize.width, height: Self.iconSize.height)
            .frame(width: 28, height: 28)
            .opacity(action?.isEnabled == false || !isMainWindow ? 0.5 : 1)

            if let badgeText = action?.badgeText, !badgeText.isEmpty {
                Text(badgeText)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 3)
                    .frame(minWidth: 12, minHeight: 11)
                    .background(Capsule().fill(Color.red))
                    .offset(x: 2, y: 1)
            }
        }
        .frame(width: 28, height: 28)
        .background(
            (isTouchDown ? BeamColor.ToolBar.buttonBackgroundClicked.swiftUI : (isHovering ? BeamColor.ToolBar.buttonBackgroundClicked.swiftUI.opacity(0.5) : Color.clear))
                .blendModeLightMultiplyDarkScreen()
        )
        .cornerRadius(6)
        .background(ViewAnchor(view: $anchorView))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTouchDown { isTouchDown = $0 }
        .simultaneousGesture(TapGesture().onEnded { performAction() })
        .tooltipOnHover(LocalizedStringKey(stringLiteral: action?.label.isEmpty == false ? action!.label : name))
        .contextMenu {
            Text(name)
            if context.webExtension.hasOptionsPage {
                Button("Settings…") {
                    WebExtensionsManager.shared.openOptionsPage(for: context.uniqueIdentifier)
                }
            }
            Button("Manage Extensions…") {
                AppDelegate.main.openPreferencesWindow(to: .extensions)
            }
        }
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text(name))
    }

    private func performAction() {
        if let action = context.action(for: tab), action.presentsPopup, action.popupPopover?.isShown == true {
            action.closePopup()
            return
        }
        WebExtensionsManager.shared.popupAnchorView = anchorView
        if let tab = tab {
            context.userGesturePerformed(in: tab)
        }
        context.performAction(for: tab)
    }
}

/// Exposes the AppKit view backing a SwiftUI view, to anchor popovers to it.
private struct ViewAnchor: NSViewRepresentable {
    @Binding var view: NSView?

    func makeNSView(context: Context) -> NSView {
        let nsView = NSView()
        DispatchQueue.main.async { view = nsView }
        return nsView
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
