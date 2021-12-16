//
//  JournalStackView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 30/03/2021.
//

import Foundation
import BeamCore

class JournalSimpleStackView: NSView {
    public var verticalSpace: CGFloat
    public var topOffset: CGFloat

    var state: BeamState
    var onStartEditing: (() -> Void)?

    var notes: [BeamNote] = []
    var views: [BeamNote: BeamTextEdit] = [:]

    override var wantsUpdateLayer: Bool { true }

    init(state: BeamState, safeTop: CGFloat, onStartEditing: (() -> Void)?, verticalSpace: CGFloat, topOffset: CGFloat) {
        self.state = state
        self.onStartEditing = onStartEditing
        self.verticalSpace = verticalSpace
        self.topOffset = topOffset
        self.safeTop = safeTop
        super.init(frame: NSRect())
        self.translatesAutoresizingMaskIntoConstraints = false
        self.layer?.backgroundColor = BeamColor.Generic.background.cgColor
        self.wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        return true
    }

    public func invalidateLayout() {
        guard !needsLayout else { return }
        invalidateIntrinsicContentSize()
    }

    override func updateLayer() {
        super.updateLayer()
        layer?.backgroundColor = BeamColor.Generic.background.cgColor
    }

    var countChanged = false
    var initialLayout = true

    var safeTop: CGFloat {
        didSet {
            if oldValue != safeTop {
                invalidateLayout()
            }
        }
    }

    //swiftlint:disable:next function_body_length
    public override func layout() {
        guard enclosingScrollView != nil else { return }
        defer {
            countChanged = false
            initialLayout = false
        }

        let textEditViews = self.notes.compactMap { views[$0] }
        var lastViewY = topOffset

        let animateMoves = countChanged && !initialLayout
        if animateMoves {
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0.2
        }

        defer {
            if animateMoves {
                NSAnimationContext.endGrouping()
            }
        }

        for textEdit in textEditViews {
            let newFrame = NSRect(origin: CGPoint(x: 0, y: lastViewY),
                                  size: NSSize(width: self.frame.width, height: textEdit.intrinsicContentSize.height))
            if !textEdit.frame.isEmpty && animateMoves {
                textEdit.animator().frame = newFrame
            } else {
                textEdit.frame = newFrame
            }

            lastViewY = (newFrame.maxY + verticalSpace).rounded()
        }
    }

    override public var intrinsicContentSize: NSSize {
        guard let firstNote = notes.first,
              let textEdit = views[firstNote]
        else { return .zero }

        let width = textEdit.intrinsicContentSize.width

        var height = topOffset
        for note in self.notes {
            if let textEdit = views[note] {
              height += textEdit.intrinsicContentSize.height + verticalSpace
            }
        }

        height += topOffset
        return NSSize(width: width, height: height)
    }

    public func setNotes(_ notes: [BeamNote], focussingOn: BeamNote?) {
        let sortedNotes = notes.sorted(by: { lhs, rhs in
            guard let j1 = lhs.type.journalDate,
                  let j2 = rhs.type.journalDate else { return false }
            return j1 > j2
        })

        defer {
            if let focus = focussingOn, let focused = views[focus] {
                DispatchQueue.main.async {
                    self.scrollToVisible(focused.frame)
                    self.window?.makeFirstResponder(focused)
                }
            }
        }

        guard self.notes != sortedNotes else {
            return
        }
        self.notes = sortedNotes

        let noteSet = Set(notes)
        for (note, view) in views {
            // Remove the notes that are there any more:
            if !noteSet.contains(note) {
                view.removeFromSuperview()
                countChanged = true
            }
        }

        for note in self.notes where note.shouldAppearInJournal || note.isTodaysNote {
            addNote(note)
        }

        if countChanged {
            invalidateLayout()
        }
    }

    public func addNote(_ note: BeamNote) {
        guard views[note] == nil else { return }
        let view = getTextEditView(for: note, enableDelayedInit: views.count > 3)
        views[note] = view
        countChanged = true
        addSubview(view)
    }

    public func getTodaysView() -> BeamTextEdit? {
        guard let note = notes.first else { return nil }
        return views[note]
    }

    private func getTextEditView(for note: BeamNote, enableDelayedInit: Bool) -> BeamTextEdit {
        let textEditView = BeamTextEdit(root: note, journalMode: true, enableDelayedInit: enableDelayedInit)
        textEditView.state = state
        textEditView.onStartEditing = onStartEditing
        textEditView.openURL = { [weak state] url, element in
            state?.handleOpenUrl(url, note: element.note, element: element)
        }
        textEditView.openCard = { [weak state] cardId, elementId, unfold in
            state?.navigateToNote(id: cardId, elementId: elementId, unfold: unfold ?? false)
        }
        textEditView.startQuery = { [weak state] textNode, animated in
            state?.startQuery(textNode, animated: animated)
        }
        textEditView.onFocusChanged = { [weak state] elementId, cursorPosition in
            state?.updateNoteFocusedState(note: note, focusedElement: elementId, cursorPosition: cursorPosition)
        }
        textEditView.minimumWidth = 800
        textEditView.maximumWidth = 1024
        textEditView.footerHeight = 0
        textEditView.topOffset = 0
        textEditView.leadingPercentage = PreferencesManager.editorLeadingPercentage
        textEditView.centerText = PreferencesManager.editorIsCentered
        textEditView.showTitle = true

        return textEditView
    }

    func updateScrollingFrames() {
    }

    override func mouseDown(with event: NSEvent) {
        // Find the nearest editor:
        let location = convert(event.locationInWindow, from: nil)
        let closest = notes.first(where: {
            guard let view = views[$0] else { return false }
            return view.frame.maxY >= location.y
        })
        if let closest = closest, let newResponder = views[closest] {
            window?.makeFirstResponder(newResponder)
        }
        super.mouseDown(with: event)
    }

}
