//
//  JournalStackView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 30/03/2021.
//

import Foundation
import BeamCore

class JournalStackView: NSView {
    public var verticalSpace: CGFloat
    public var topOffset: CGFloat

    var state: BeamState
    var onStartEditing: (() -> Void)?

    private var notes: [BeamNote] = []
    private var views: [BeamNote: BeamTextEdit] = [:]

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
        needsLayout = true
        setNeedsDisplay(bounds)
    }

    override func updateLayer() {
        super.updateLayer()
        layer?.backgroundColor = BeamColor.Generic.background.cgColor
    }

    public override func layout() {
        relayoutSubViews()
        super.layout()
    }

    var countChanged = false
    var initialLayout = true

    var safeTop: CGFloat { didSet { invalidateIntrinsicContentSize() } }

    //swiftlint:disable:next function_body_length
    private func relayoutSubViews() {
        guard let scrollView = enclosingScrollView else { return }
        defer {
            countChanged = false
            initialLayout = false
        }

        var secondNoteY = CGFloat(0)
        let clipView = scrollView.contentView

        let textEditViews = self.notes.compactMap { views[$0] }
        var lastViewY = topOffset
        var first = true

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

        let scrollPosition = clipView.bounds.origin.y
        let clipHeight = clipView.bounds.height

        for textEdit in textEditViews {
            if first {
                let firstNoteHeight = topOffset + textEdit.intrinsicContentSize.height + verticalSpace
                secondNoteY = max(clipHeight, firstNoteHeight) - safeTop

                if scrollPosition <= secondNoteY - (topOffset + textEdit.intrinsicContentSize.height + safeTop) {
                    if textEdit.superview == self {
                        enclosingScrollView?.addFloatingSubview(textEdit, for: .vertical)
                    }

                    let elastic = min(0, safeTop + scrollPosition)
                    let posY = topOffset - elastic
                    let newFrame = NSRect(origin: CGPoint(x: 0, y: posY),
                                          size: NSSize(width: self.frame.width, height: textEdit.intrinsicContentSize.height))
                    textEdit.frame = newFrame
                    lastViewY = secondNoteY
                    first = false
                    continue
                }
                lastViewY = secondNoteY - textEdit.intrinsicContentSize.height - verticalSpace
                if textEdit.superview != self {
                    addSubview(textEdit)
                }
            }
            let newFrame = NSRect(origin: CGPoint(x: 0, y: lastViewY),
                                  size: NSSize(width: self.frame.width, height: textEdit.intrinsicContentSize.height))
            if !textEdit.frame.isEmpty && !first && animateMoves {
                textEdit.animator().frame = newFrame
            } else {
                textEdit.frame = newFrame
            }

            lastViewY = (first ? secondNoteY : newFrame.maxY + verticalSpace).rounded()
            first = false
        }
    }

    override public var intrinsicContentSize: NSSize {
        guard let firstNote = notes.first,
              let textEdit = views[firstNote],
              let scrollView = enclosingScrollView
        else { return .zero }

        let width = textEdit.intrinsicContentSize.width
        let clipView = scrollView.contentView
        let clipHeight = clipView.bounds.height
        let firstNoteHeight = topOffset + textEdit.intrinsicContentSize.height + verticalSpace
        let secondNoteY = max(clipHeight, firstNoteHeight) - safeTop

        var height = secondNoteY
        var first = true
        for note in self.notes {
            if !first, let textEdit = views[note] {
              height += textEdit.intrinsicContentSize.height + verticalSpace
            }
            first = false
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
            invalidateIntrinsicContentSize()
        }
        layout()
    }

    public func addNote(_ note: BeamNote) {
        guard views[note] == nil else { return }
        let view = getTextEditView(for: note)
        views[note] = view
        countChanged = true
        addSubview(view)
    }

    public func getTodaysView() -> BeamTextEdit? {
        guard let note = notes.first else { return nil }
        return views[note]
    }

    private func getTextEditView(for note: BeamNote) -> BeamTextEdit {
        let textEditView = BeamTextEdit(root: note, journalMode: true)
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
        relayoutSubViews()
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
