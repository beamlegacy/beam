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

    static func dockedPanelOrigin(from mainWindowFrame: NSRect) -> CGPoint {
        CGPoint(x: mainWindowFrame.origin.x + mainWindowFrame.width + 5, y: mainWindowFrame.origin.y)
    }

    static func presentMiniEditor(from window: BeamWindow, with note: BeamNote, at frame: CGRect? = nil) {
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
        super.init(contentRect: rect, styleMask: [.fullSizeContentView, .borderless], backing: .buffered, defer: false)

        self.title = note.title

        let mainView = MiniEditor(note: note, window: self)
            .environmentObject(state)
            .environmentObject(data)
            .environmentObject(windowInfo)
            .environmentObject(state.browserTabsManager)
            .cornerRadius(10)

        let hostingView = NSHostingView(rootView: mainView)
        self.contentView = hostingView

        self.isReleasedWhenClosed = false
        self.isOpaque = false
        self.backgroundColor = .clear

        AppDelegate.main.panels[note] = self

        windowInfo.window = self
        windowInfo.windowFrame = frame

        self.delegate = self
    }

    func reDock() {
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
        parent?.removeChildWindow(self)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        self.styleMask.insert(.resizable)
    }

    override var canBecomeKey: Bool {
        return true
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        isMouseDown = true

        if allowsWindowDragging(with: event) {
            performDrag(with: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)

        if isCloseToMainWindow() && wasJustDragged {
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
        if isCloseToMainWindow() && isMouseDown {
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
        return CGSize(width: frameSize.width.clamp(Self.minimumPanelWidth, Self.maximumPanelWidth), height: max(frameSize.height, minSize.height + 51))
    }

    fileprivate func allowsWindowDragging(with event: NSEvent) -> Bool {
        event.locationInWindow.flippedPointToTopLeftOrigin(in: self).y < 40
    }
}

import SwiftUI
struct MiniEditor: View {

    let note: BeamNote
    weak var window: MiniEditorPanel?

    @EnvironmentObject var state: BeamState
    @EnvironmentObject var windowInfo: BeamWindowInfo

    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { proxy in
                NoteView(note: note, containerGeometry: proxy, topInset: 0, leadingPercentage: 0, centerText: false)
                HStack {
                    ButtonLabel(icon: "tabs-side_close", customStyle: buttonStyle) {
                        if let window = window {
                            window.close()
                        } else {
                            state.sideNote = nil
                        }
                    }
                    Spacer()
                    if let window = window, window.parent == nil {
                        Button("Re-Dock") {
                            window.reDock()
                        }
                    }
                    if let window = windowInfo.window as? BeamWindow {
                        ButtonLabel(icon: "tabs-side_detach", customStyle: buttonStyle) {
                            let frame = proxy.frame(in: .global)
                            MiniEditorPanel.presentMiniEditor(from: window, with: note, at: window.convertToScreen(frame).offsetBy(dx: 20, dy: -20))
                            state.sideNote = nil
                        }
                    } else if let window = windowInfo.window as? MiniEditorPanel {
                        ButtonLabel(icon: "tabs-side_openmain", customStyle: buttonStyle) {
                            state.sideNote = note
                            window.close()
                        }
                    }
                }
                .padding(10)
                .background(VisualEffectView(material: .headerView))
            }
        }
        .background(BeamColor.Generic.background.swiftUI)
        .cornerRadius(10)
    }

    private var buttonStyle: ButtonLabelStyle {
        ButtonLabelStyle(iconSize: 12, activeBackgroundColor: .clear)
    }
}
