//
//  JournalStackView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 30/03/2021.
//

import Foundation
import BeamCore
import Combine

class JournalSimpleStackView: NSView, BeamTextEditContainer {
    public var verticalSpace: CGFloat
    public var topOffset: CGFloat {
        didSet {
            if oldValue != topOffset {
                initialLayout = true
                invalidateIntrinsicContentSize()
            }
        }
    }

    weak var state: BeamState!
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
        BeamData.shared.$lastIndexedElement
            .debounce(for: 2, scheduler: RunLoop.current)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, self.state.mode == .today else { return }
                self.setNotes(self.notes, focussingOn: nil, force: true)
            }.store(in: &scope)

        state.data.$journal
            .receive(on: DispatchQueue.main)
            .sink { [weak self] journalNotes in
            guard let self = self else { return }
            self.setNotes(journalNotes, focussingOn: self.state.journalNoteToFocus, force: false)
        }.store(in: &scope)

        state.$journalNoteToFocus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] focusedNote in
            guard let self = self else { return }
            self.setNotes(self.notes, focussingOn: focusedNote, force: true)
        }.store(in: &scope)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        return true
    }

    private var layoutInvalidated = false
    private var inLayout = false
    public func invalidateLayout() {
        guard !layoutInvalidated, !inLayout else { return }
        layoutInvalidated = true
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    override func updateLayer() {
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

    public override func layout() {
        super.layout()

        guard enclosingScrollView != nil else { return }

        inLayout = true
        defer {
            layoutInvalidated = false
            inLayout = false
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

        updateScrollingFrames()
    }

    override public var intrinsicContentSize: NSSize {
        let width = AppDelegate.defaultWindowMinimumSize.width

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
        guard let currentDatabaseId = BeamData.shared.currentDatabase?.id,
              databaseId != currentDatabaseId
        else { return }
        self.notes.removeAll()
        for view in views.values {
            view.removeFromSuperview()
        }
        views.removeAll()
        databaseId = currentDatabaseId
    }

    private func setNotes(_ notes: [BeamNote], focussingOn: BeamNote?, force: Bool) {
        inspectDatabaseChange()

        #if DEBUG
        //print("JournalStackView.setNotes \(notes)")
        defer {
            let mismatching = self.notes.compactMap({ (views[$0]?.note) === $0 ? nil : $0 })
            print("Mismatching note with note views: \(mismatching)")
        }
        #endif

        let sortedNotes = notes.sorted(by: { lhs, rhs in
            guard let j1 = lhs.type.journalDate,
                  let j2 = rhs.type.journalDate else { return false }
            return j1 > j2
        })

        defer {
            if let focus = focussingOn, let focused = views[focus] {
                DispatchQueue.main.async { [self] in
                    scrollToVisible(focused.frame)
                    window?.makeFirstResponder(focused)
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
                DispatchQueue.main.async {
                    view.removeFromSuperview()
                }
                views.removeValue(forKey: note)
            }
        }

        if !insertedViews.isEmpty || !removedViews.isEmpty {
            needsLayout = true
        }
    }

    private let typicalEditorHeightWhenWeDontKnow = CGFloat(800)
    public func addNote(_ note: BeamNote, forceInit: Bool) {
        // Remove views for notes that have changed without changing ids:
        guard views[note] == nil else {
            views[note]?.note = note
            return
        }
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
        let textEditView = BeamTextEdit(root: note, journalMode: true, enableDelayedInit: enableDelayedInit, frame: NSRect(origin: .zero, size: CGSize(width: frame.width, height: BeamTextEdit.minimumEmptyEditorHeight)), state: state)
        textEditView.onStartEditing = onStartEditing
        textEditView.openURL = { [weak state] url, element, inBackground in
            state?.handleOpenURLFromNote(url, note: element.note, element: element, inBackground: inBackground)
        }
        textEditView.openNote = { [weak state] noteId, elementId, unfold, inSplitView in
            if inSplitView == true {
                state?.openNoteInSplitView(id: noteId)
            } else {
                state?.navigateToNote(id: noteId, elementId: elementId, unfold: unfold ?? false)
            }
        }
        textEditView.startQuery = { [weak state] textNode, animated in
            state?.startQuery(textNode, animated: animated)
        }
        textEditView.onFocusChanged = { [weak state] elementId, cursorPosition, selectedRange, isReference, nodeSelectionState in
            state?.currentJournalNoteID = note.id
            state?.updateNoteFocusedState(note: note,
                                          focusedElement: elementId,
                                          cursorPosition: cursorPosition,
                                          selectedRange: selectedRange,
                                          isReference: isReference,
                                          nodeSelectionState: nodeSelectionState)
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

    private var otherNotesAlpha = CGFloat(0)
    func updateScrollingFrames() {
        guard let scrollView = enclosingScrollView else { return }
        let clipView = scrollView.contentView
        let minFadingOffset = ModeView.omniboxEndFadeOffsetFor(height: scrollView.bounds.height)
        DispatchQueue.main.async { [weak self] in
            self?.state.journalScrollOffset = clipView.bounds.minY
        }
        otherNotesAlpha = min(1, clipView.bounds.minY / minFadingOffset)

        var first = true
        for note in notes {
            guard let view = views[note] else { continue }
            if first {
                first = false
                if view.alphaValue != 1.0 {
                    view.alphaValue = 1.0
                    view.enabled = true
                }
            } else {
                if view.alphaValue != otherNotesAlpha {
                    view.alphaValue = otherNotesAlpha
                    view.enabled = otherNotesAlpha >= 0.25
                }
            }
        }
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
        guard let window = window else { return }

        initialLayout = false
        if let offset = state.lastScrollOffset[UUID.null],
           let clipView = enclosingScrollView?.contentView,
           clipView.bounds.origin.y != offset {
            scroll(NSPoint(x: 0, y: offset))
        }

        if let noteID = state.currentJournalNoteID,
           let fs = state.notesFocusedStates.getSavedNoteFocusedState(noteId: noteID),
           let note = notes.first(where: { $0.id == noteID }),
           let view = views[note] {
            view.focusElement(id: fs.elementId,
                              cursorPosition: fs.cursorPosition,
                              selectedRange: fs.selectedRange,
                              isReference: fs.isReference,
                              nodeSelectionState: fs.nodeSelectionState,
                              highlight: fs.highlight,
                              unfold: fs.unfold,
                              scroll: false,
                              notify: false)
            window.makeFirstResponder(view)
        }
    }

    func scrollToTop(animated: Bool) {
        guard let scrollView = enclosingScrollView else { return }
        let y = -scrollView.contentInsets.top
        if animated {
            scroll(toVerticalOffset: y)
        } else {
            scroll(CGPoint(x: 0, y: y))
        }
    }

    func scroll(toVerticalOffset verticalOffset: CGFloat) {
        guard let scrollView = enclosingScrollView else { return }
        let clipView = scrollView.contentView
        let animationDuration = 0.3
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = animationDuration
        var p = clipView.bounds.origin
        p.y = verticalOffset

        clipView.animator().setBoundsOrigin(p)
        scrollView.reflectScrolledClipView(clipView)
        NSAnimationContext.endGrouping()
    }
}
