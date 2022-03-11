//
//  JournalStackView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 30/03/2021.
//

import Foundation
import BeamCore
import Combine

class JournalSimpleStackView: NSView {
    public var verticalSpace: CGFloat
    public var topOffset: CGFloat

    var state: BeamState
    var onStartEditing: (() -> Void)?

    var notes: [BeamNote] = []
    var views: [BeamNote: BeamTextEdit] = [:]
    var scope: [AnyCancellable] = []

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

        observeNotesChanges()
    }

    func observeNotesChanges() {
        // automatically rescan the journal when the notes change:
        AppDelegate.main.data.$lastIndexedElement
            .throttle(for: 2, scheduler: RunLoop.current, latest: true)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.setNotes(self.notes, focussingOn: nil, force: true)
            }.store(in: &scope)
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

    var initialLayout = true

    var safeTop: CGFloat {
        didSet {
            if oldValue != safeTop {
                invalidateLayout()
            }
        }
    }

    var insertedViews = Set<BeamTextEdit>()
    var removedViews = Set<BeamTextEdit>()

    //swiftlint:disable:next function_body_length
    public override func layout() {
        guard enclosingScrollView != nil else { return }
        defer {
            insertedViews.removeAll()
            removedViews.removeAll()
        }

        let textEditViews = self.notes.compactMap { views[$0] }
        var lastViewY = topOffset

        let animateMoves = !initialLayout

        for textEdit in textEditViews {
            let newFrame = NSRect(origin: CGPoint(x: 0, y: lastViewY),
                                  size: NSSize(width: self.frame.width, height: textEdit.intrinsicContentSize.height))

            if animateMoves && !insertedViews.contains(textEdit) {
                NSAnimationContext.beginGrouping()
                NSAnimationContext.current.duration = 0.2
                textEdit.animator().frame = newFrame
                NSAnimationContext.endGrouping()
            } else {
                textEdit.frame = newFrame
            }
            lastViewY = (newFrame.maxY + verticalSpace).rounded()
        }
    }

    override public var intrinsicContentSize: NSSize {
        let width = BeamTextEdit.minimumEmptyEditorWidth

        var height = topOffset
        for note in self.notes {
            if let textEdit = views[note] {
              height += textEdit.intrinsicContentSize.height + verticalSpace
            }
        }

        height += topOffset
        return NSSize(width: width, height: height)
    }

    private var databaseId = UUID.null
    private func inspectDatabaseChange() {
        guard databaseId != DatabaseManager.defaultDatabase.id else { return }
        self.notes.removeAll()
        for view in views.values {
            view.removeFromSuperview()
        }
        views.removeAll()
        databaseId = DatabaseManager.defaultDatabase.id
    }

    //swiftlint:disable:next cyclomatic_complexity function_body_length
    public func setNotes(_ notes: [BeamNote], focussingOn: BeamNote?, force: Bool) {
        inspectDatabaseChange()

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

        guard force || self.notes != sortedNotes else {
            return
        }
        self.notes = sortedNotes

        let noteSet = Set(notes)

        for note in noteSet {
            // Remove the notes that are not there any more:
            if note.shouldAppearInJournal {
                let forceInit: Bool = {
                    guard let j1 = note.type.journalDate,
                          let j2 = focussingOn?.type.journalDate else { return false }

                    return j1 >= j2
                }()

                addNote(note, forceInit: forceInit)
            } else {
                guard let view = views[note] else { continue }
                view.removeFromSuperview()
                removedViews.insert(view)
                views.removeValue(forKey: note)
            }
        }

        let viewsCopy = views
        for tuple in viewsCopy {
            let note = tuple.key
            // Remove the notes that are not there any more:
            if !noteSet.contains(note) {
                let view = tuple.value
                view.removeFromSuperview()
                views.removeValue(forKey: note)
            }
        }

        if !insertedViews.isEmpty || !removedViews.isEmpty {
            layout()
        }
    }

    private let typicalEditorHeightWhenWeDontKnow = CGFloat(800)
    public func addNote(_ note: BeamNote, forceInit: Bool) {
        guard views[note] == nil else { return }
        let maxHeight: CGFloat
        if frame.height > 0 {
            maxHeight = frame.height
        } else if let windowHeight = window?.frame.height {
            maxHeight = windowHeight
        } else if let screen = window?.screen ?? NSScreen.main {
            maxHeight = screen.frame.height
        } else {
            maxHeight = typicalEditorHeightWhenWeDontKnow
        }
        let delayInit = forceInit ? false : (views.count > 1 + Int(maxHeight / BeamTextEdit.minimumEmptyEditorHeight))
        let view = getTextEditView(for: note, enableDelayedInit: delayInit)
        views[note] = view
        addSubview(view)
        insertedViews.insert(view)
        return
    }

    public func getTodaysView() -> BeamTextEdit? {
        guard let note = notes.first else { return nil }
        return views[note]
    }

    private func getTextEditView(for note: BeamNote, enableDelayedInit: Bool) -> BeamTextEdit {
        let textEditView = BeamTextEdit(root: note, journalMode: true, enableDelayedInit: enableDelayedInit, frame: NSRect(origin: .zero, size: CGSize(width: frame.width, height: BeamTextEdit.minimumEmptyEditorHeight)))
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
        textEditView.footerHeight = 73
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

    override func viewDidMoveToWindow() {
        initialLayout = false
        if let offset = state.lastScrollOffset[UUID.null] {
            scroll(NSPoint(x: 0, y: offset))
        }
    }
}
