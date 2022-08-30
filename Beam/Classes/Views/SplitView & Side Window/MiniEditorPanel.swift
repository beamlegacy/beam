//
//  MiniEditorPanel.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 24/06/2022.
//

import AppKit
import BeamCore

class MiniEditorPanel: NSPanel {

    let note: BeamNote
    let data: BeamData
    let state: BeamState
    var windowInfo: BeamWindowInfo = BeamWindowInfo()

    private(set) var wasJustDragged = false
    private var moveNotificationToken: NSObjectProtocol?
    private var isMouseDown = false

    static let minimumPanelWidth: CGFloat = 550
    static let maximumPanelWidth: CGFloat = 614

    private let enableWindowDocking = false

    static func dockedPanelOrigin(from mainWindowFrame: NSRect) -> CGPoint {
        CGPoint(x: mainWindowFrame.origin.x + mainWindowFrame.width + 5, y: mainWindowFrame.origin.y)
    }

    static func presentMiniEditor(with note: BeamNote, from window: BeamWindow, frame: CGRect? = nil) {
        guard Configuration.branchType == .develop else { return }

        let state = window.state
        guard state.associatedPanel(for: note) == nil else {
            state.associatedPanel(for: note)?.makeKeyAndOrderFront(nil)
            return
        }

        let idealWidth = panelWidth(for: window)
        let panelSize = CGSize(width: idealWidth, height: window.frame.height)
        let position = dockedPanelOrigin(from: window.frame)

        let miniEditor = MiniEditorPanel(note: note, state: state, rect: frame ?? NSRect(origin: position, size: panelSize))
        if frame == nil {
            window.addChildWindow(miniEditor, ordered: .above)
        }
        miniEditor.makeKeyAndOrderFront(nil)
    }

    static func panelWidth(for originWindow: BeamWindow) -> CGFloat {
        max(originWindow.frame.width / 2, minimumPanelWidth)
    }

    init(note: BeamNote, state: BeamState, rect: NSRect) {
        self.note = note
        self.data = state.data
        self.state = state
        super.init(contentRect: rect, styleMask: [.titled, .closable, .miniaturizable, .resizable, .unifiedTitleAndToolbar, .fullSizeContentView], backing: .buffered, defer: false)

        self.title = note.title

        let mainView = MiniEditor(note: note, window: self)
            .environmentObject(state)
            .environmentObject(data)
            .environmentObject(windowInfo)
            .environmentObject(state.browserTabsManager)
            .cornerRadius(10)
            .ignoresSafeArea()

        let hostingView = NSHostingView(rootView: mainView)
        self.contentView = hostingView
        self.isReleasedWhenClosed = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden

        AppDelegate.main.panels[note] = self

        windowInfo.window = self
        windowInfo.windowFrame = frame

        self.delegate = self
    }

    func reDock() {
        guard enableWindowDocking else { return }
        guard let mainWindow = state.associatedWindow as? BeamWindow else { return }
        let position = MiniEditorPanel.dockedPanelOrigin(from: mainWindow.frame)
        let rect = CGRect(origin: position, size: CGSize(width: Self.panelWidth(for: mainWindow), height: mainWindow.frame.height))

        Task { @MainActor in
            await NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.1
                context.allowsImplicitAnimation = true
                self.animator().setFrame(rect, display: false, animate: true)
            }
            mainWindow.addChildWindow(self, ordered: .above)
            self.styleMask.remove(.resizable)
            windowInfo.windowFrame = rect
        }
    }

    func unDock() {
        guard enableWindowDocking else { return }
        parent?.removeChildWindow(self)
        if PreferencesManager.isHapticFeedbackOn {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        self.styleMask.insert(.resizable)
    }

    override var canBecomeKey: Bool {
        return true
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        isMouseDown = true
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)

        if isCloseToMainWindow() && wasJustDragged && enableWindowDocking {
            reDock()
        }
        self.wasJustDragged = false
        isMouseDown = false
    }

    override func close() {
        AppDelegate.main.panels[note] = nil
        super.close()
    }

    private func isCloseToMainWindow() -> Bool {
        guard let mainWindow = state.associatedWindow else { return false }
        let trailingEdgeX = mainWindow.frame.maxX
        let panelLeadingEdgeX = self.frame.origin.x

        return abs(trailingEdgeX - panelLeadingEdgeX) < 10
    }
}

extension MiniEditorPanel: NSWindowDelegate {

    func windowDidResize(_ notification: Notification) {
        if let parent = parent, windowInfo.windowIsResizing {
            let topLeft = CGPoint(x: parent.frame.origin.x, y: parent.frame.origin.y + parent.frame.height)
            let newParentOrigin = CGPoint(x: topLeft.x, y: topLeft.y - self.frame.height)
            let parentFrame = CGRect(origin: newParentOrigin, size: CGSize(width: parent.frame.width, height: self.frame.height))
            parent.setFrame(parentFrame, display: false)
        }

        windowInfo.windowFrame = self.frame
    }

    func windowDidMove(_ notification: Notification) {
        if isCloseToMainWindow() && isMouseDown && PreferencesManager.isHapticFeedbackOn {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }

        if parent != nil, !isCloseToMainWindow() {
            unDock()
        }

        windowInfo.windowFrame = self.frame
    }

    func windowWillMove(_ notification: Notification) {
        if isMouseDown {
            wasJustDragged = true
        }
    }

    func windowWillStartLiveResize(_ notification: Notification) {
        self.windowInfo.windowIsResizing = true
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        self.windowInfo.windowIsResizing = false
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        let minSize = AppDelegate.defaultWindowMinimumSize
        return CGSize(width: max(frameSize.width, Self.minimumPanelWidth), height: max(frameSize.height, minSize.height + 51))
    }
}

import SwiftUI
struct MiniEditor: View {

    let note: BeamNote
    weak var window: MiniEditorPanel?

    @EnvironmentObject var state: BeamState
    @EnvironmentObject var windowInfo: BeamWindowInfo

    @State private var showTitle: Bool = false
    @State private var contentIsScrolled = false

    private var titleHideVerticalOffset: CGFloat {
        isInWindow ? 135 : 111
    }
    private var toolbarHeight: CGFloat {
        isInWindow ? 28 : 52
    }

    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { proxy in
                NoteView(note: note, containerGeometry: proxy, topInset: 0, leadingPercentage: 0, centerText: false) { offset in
                    showTitle = offset.y > titleHideVerticalOffset ? true : false
                    let isScrolled = offset.y > NoteView.topSpacingBeforeTitle - toolbarHeight
                    contentIsScrolled = isScrolled
                }
                HStack(spacing: 8) {
                    Spacer()
                    if let _ = windowInfo.window as? BeamWindow {
                        ButtonLabel(icon: "tabs-side_detach", customStyle: buttonStyle) {
                            state.openNoteInMiniEditor(id: note.id)
                            state.sideNote = nil
                        }.frame(width: 12, height: 12)
                    } else if let window = windowInfo.window as? MiniEditorPanel {
                        ButtonLabel(icon: "tabs-side_openmain", customStyle: buttonStyle) {
                            state.sideNote = note
                            window.close()
                        }.frame(width: 12, height: 12)
                    }
                    if !isInWindow {
                        ButtonLabel(icon: "tabs-side_close", customStyle: buttonStyle) {
                            state.sideNote = nil
                        }.frame(width: 12, height: 12)
                    }
                }
                .padding(.trailing, isInWindow ? 8 : 20)
                .frame(height: toolbarHeight)
                .overlay(titleView)
                .background(VisualEffectView(material: .headerView)
                                .overlay(blurOverlay)
                                .opacity(contentIsScrolled || !windowInfo.windowIsMain ? 1 : 0))
            }
        }
        .background(BeamColor.Generic.background.swiftUI)
    }

    @ViewBuilder private var titleView: some View {
        if showTitle {
            Text(note.title)
                .transition(.opacity.animation(.easeInOut))
                .font(isInWindow ? Font.system(size: 13, weight: .bold, design: .default) : BeamFont.regular(size: 11).swiftUI)
                .foregroundColor(BeamColor.Niobium.swiftUI)
        }
    }

    private var isInWindow: Bool {
        window != nil
    }

    private var buttonStyle: ButtonLabelStyle {
        ButtonLabelStyle(iconSize: 12, activeBackgroundColor: .clear)
    }

    private let overlayOpacity = PreferencesManager.editorToolbarOverlayOpacity
    private var blurOverlay: some View {
        VStack(spacing: 0) {
            if windowInfo.windowIsMain {
                BeamColor.Generic.background.swiftUI.opacity(overlayOpacity)
                Separator(horizontal: true, hairline: true, color: BeamColor.ToolBar.backgroundBottomSeparator)
            } else {
                BeamColor.ToolBar.backgroundInactiveWindow.swiftUI
                Separator(horizontal: true, hairline: true, color: BeamColor.ToolBar.backgroundBottomSeparatorInactiveWindow)
            }
        }
    }
}
