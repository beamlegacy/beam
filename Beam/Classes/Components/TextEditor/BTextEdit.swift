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

public struct BTextEdit: NSViewRepresentable {
    var note: BeamNote
    var data: BeamData
    var openURL: (URL) -> Void
    var openCard: (String) -> Void
    var onStartEditing: () -> Void = { }
    var onEndEditing: () -> Void = { }
    var onStartQuery: (TextNode) -> Void = { _ in }
    var minimumWidth: CGFloat = 800
    var maximumWidth: CGFloat = 1024

    var leadingAlignment: CGFloat = 160
    var traillingPadding: CGFloat = 80
    var topOffset: CGFloat = 45
    var footerHeight: CGFloat = 0

    var centerText = false
    var showTitle = true

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> BeamTextEdit {
        let nsView = BeamTextEdit(root: note, font: Font.main, journalMode: true)

        nsView.openURL = openURL
        nsView.openCard = openCard
        nsView.onStartEditing = onStartEditing
        nsView.onEndEditing = onEndEditing
        nsView.onStartQuery = onStartQuery

        nsView.minimumWidth = minimumWidth
        nsView.maximumWidth = maximumWidth

        nsView.leadingAlignment = leadingAlignment
        nsView.traillingPadding = traillingPadding
        nsView.topOffset = topOffset
        nsView.footerHeight = footerHeight

        nsView.centerText = centerText
        nsView.showTitle = showTitle

        return nsView
    }

    public func updateNSView(_ nsView: BeamTextEdit, context: Context) {
        if nsView.note !== note {
            nsView.note = note
        }

        nsView.data = data
        nsView.openURL = openURL
        nsView.openCard = openCard
        nsView.onStartEditing = onStartEditing
        nsView.onEndEditing = onEndEditing
        nsView.onStartQuery = onStartQuery

        nsView.minimumWidth = minimumWidth
        nsView.maximumWidth = maximumWidth

        nsView.leadingAlignment = leadingAlignment
        nsView.traillingPadding = traillingPadding
        nsView.topOffset = topOffset
        nsView.footerHeight = footerHeight

        nsView.centerText = centerText
        nsView.showTitle = showTitle

        context.coordinator.onDeinit = {
            nsView.hideFloatingView()
        }
    }

    public class Coordinator: NSObject {
        let parent: BTextEdit
        var onDeinit: () -> Void = {}

        init(_ edit: BTextEdit) {
            self.parent = edit
        }

        deinit {
            onDeinit()
        }
    }

    public typealias NSViewType = BeamTextEdit
}

public struct BTextEditScrollable: NSViewRepresentable {
    var note: BeamNote
    var data: BeamData
    var openURL: (URL) -> Void
    var openCard: (String) -> Void
    var onStartEditing: () -> Void = { }
    var onEndEditing: () -> Void = { }
    var onStartQuery: (TextNode) -> Void = { _ in }
    var minimumWidth: CGFloat = 800
    var maximumWidth: CGFloat = 1024

    var leadingAlignment = CGFloat(160)
    var traillingPadding = CGFloat(80)
    var topOffset = CGFloat(28)
    var footerHeight = CGFloat(28)

    var centerText = false
    var showTitle = true

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> NSViewType {
        let edit = BeamTextEdit(root: note, font: Font.main, journalMode: false)

        edit.data = data
        edit.openURL = openURL
        edit.openCard = openCard
        edit.onStartEditing = onStartEditing
        edit.onEndEditing = onEndEditing
        edit.onStartQuery = onStartQuery

        edit.minimumWidth = minimumWidth
        edit.maximumWidth = maximumWidth

        edit.leadingAlignment = leadingAlignment
        edit.traillingPadding = traillingPadding
        edit.topOffset = topOffset
        edit.footerHeight = footerHeight

        edit.centerText = centerText
        edit.showTitle = showTitle

        let scrollView = NSScrollView()

        let clipView = NSClipView()
        clipView.translatesAutoresizingMaskIntoConstraints = false
        clipView.drawsBackground = false
        scrollView.contentView = clipView
        clipView.addConstraint(NSLayoutConstraint(item: clipView, attribute: .left, relatedBy: .equal, toItem: edit, attribute: .left, multiplier: 1.0, constant: 0))
        clipView.addConstraint(NSLayoutConstraint(item: clipView, attribute: .top, relatedBy: .equal, toItem: edit, attribute: .top, multiplier: 1.0, constant: 0))
        clipView.addConstraint(NSLayoutConstraint(item: clipView, attribute: .right, relatedBy: .equal, toItem: edit, attribute: .right, multiplier: 1.0, constant: 0))

        edit.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.documentView = edit

        return scrollView
    }

    public func updateNSView(_ nsView: NSViewType, context: Context) {
        guard let edit = nsView.documentView as? BeamTextEdit else { return }

        if edit.note !== note {
            edit.note = note
        }

        edit.openURL = openURL
        edit.openCard = openCard
        edit.onStartEditing = onStartEditing
        edit.onEndEditing = onEndEditing
        edit.onStartQuery = onStartQuery

        edit.minimumWidth = minimumWidth
        edit.maximumWidth = maximumWidth

        edit.leadingAlignment = leadingAlignment
        edit.traillingPadding = traillingPadding
        edit.topOffset = topOffset
        edit.footerHeight = footerHeight

        edit.centerText = centerText
        edit.showTitle = showTitle

        context.coordinator.onDeinit = {
            edit.hideFloatingView()
        }
    }

    public class Coordinator: NSObject {
        let parent: BTextEditScrollable
        var onDeinit: () -> Void = {}

        init(_ edit: BTextEditScrollable) {
            self.parent = edit
        }

        deinit {
            onDeinit()
        }
    }

    public typealias NSViewType = NSScrollView
}
