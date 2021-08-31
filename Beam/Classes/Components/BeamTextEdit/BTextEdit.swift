//
//  BTextEdit.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/12/2020.
//

import Foundation
import SwiftUI
import AppKit
import Combine
import BeamCore

public struct BTextEditScrollable: NSViewRepresentable {
    public typealias NSViewType = NSScrollView

    var note: BeamNote
    var data: BeamData
    var openURL: (URL, BeamElement) -> Void
    var openCard: (_ noteId: UUID, _ elementId: UUID?, _ unfold: Bool?) -> Void
    var startQuery: (TextNode, Bool) -> Void = { _, _ in }

    var onStartEditing: () -> Void = { }
    var onEndEditing: () -> Void = { }
    var onFocusChanged: ((UUID, Int) -> Void)?
    var onScroll: ((CGPoint) -> Void)?

    var minimumWidth: CGFloat = 800
    var maximumWidth: CGFloat = 1024
    var topOffset = CGFloat(28)
    var footerHeight = CGFloat(28)
    var leadingPercentage = PreferencesManager.editorLeadingPercentage
    var centerText = PreferencesManager.editorIsCentered
    var showTitle = true
    var initialFocusedState: NoteEditFocusedState?

    var headerView: AnyView?

    private let focusOnAppear = true

    public func makeCoordinator() -> BTextEditScrollableCoordinator {
        BTextEditScrollableCoordinator(self)
    }

    public func makeNSView(context: Context) -> NSViewType {
        let edit = BeamTextEdit(root: note, journalMode: false)

        edit.data = data
        updateEditorProperties(edit, context: context)

        let scrollView = buildScrollView()
        edit.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = edit
        scrollView.contentView.addConstraints([
            scrollView.contentView.leftAnchor.constraint(equalTo: edit.leftAnchor),
            scrollView.contentView.rightAnchor.constraint(equalTo: edit.rightAnchor),
            scrollView.contentView.topAnchor.constraint(equalTo: edit.topAnchor)
        ])

        updateHeaderView(scrollView, context: context)
        if focusOnAppear {
            focusEditor(edit)
        }

        return scrollView
    }

    public func updateNSView(_ nsView: NSViewType, context: Context) {
        guard let edit = nsView.documentView as? BeamTextEdit else { return }

        updateEditorProperties(edit, context: context)
        if edit.note !== note {
            edit.note = note
            if focusOnAppear {
                focusEditor(edit)
            }
        }

        updateHeaderView(nsView, context: context)
        context.coordinator.onDeinit = { [weak edit] in
            edit?.hideInlineFormatter()
        }
    }

    private func updateEditorProperties(_ editor: BeamTextEdit, context: Context) {
        editor.openURL = openURL
        editor.openCard = openCard
        editor.startQuery = startQuery

        editor.onStartEditing = onStartEditing
        editor.onEndEditing = onEndEditing
        editor.onFocusChanged = onFocusChanged

        editor.minimumWidth = minimumWidth
        editor.maximumWidth = maximumWidth
        editor.topOffset = topOffset
        editor.footerHeight = footerHeight
        editor.leadingPercentage = leadingPercentage
        editor.centerText = centerText

        editor.showTitle = showTitle
    }

    private func focusEditor(_ editor: BeamTextEdit) {
        editor.scroll(.zero)
        DispatchQueue.main.async {
            if let fs = initialFocusedState {
                editor.focusElement(withId: fs.elementId, atCursorPosition: fs.cursorPosition, highlight: fs.highlight, unfold: fs.unfold)
            }
            editor.window?.makeFirstResponder(editor)
        }
    }

    private func updateHeaderView(_ scrollView: NSViewType, context: Context) {
        guard let headerView = headerView, let documentView = scrollView.documentView
        else { return }
        context.coordinator.headerHostingView?.removeFromSuperview()
        let hosting = NSHostingView<AnyView>(rootView: headerView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(hosting)
        documentView.addConstraints([
            hosting.leftAnchor.constraint(equalTo: documentView.leftAnchor),
            hosting.rightAnchor.constraint(equalTo: documentView.rightAnchor),
            hosting.topAnchor.constraint(equalTo: documentView.topAnchor)
        ])
        context.coordinator.headerHostingView = hosting
    }

    private func buildScrollView() -> NSScrollView {
        let clipView = NSClipView()
        clipView.translatesAutoresizingMaskIntoConstraints = false
        clipView.drawsBackground = false

        let scrollView = NSScrollView()
        scrollView.contentView = clipView
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        return scrollView
    }
}

extension BTextEditScrollable {
    public class BTextEditScrollableCoordinator: NSObject {
        private let parent: BTextEditScrollable
        fileprivate var onDeinit: () -> Void = {}
        fileprivate var headerHostingView: NSHostingView<AnyView>?

        init(_ edit: BTextEditScrollable) {
            self.parent = edit
        }

        deinit {
            onDeinit()
        }
    }
}
