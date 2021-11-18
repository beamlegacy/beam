//
//  BeamTextEdit+SlashMenu.swift
//  Beam
//
//  Created by Remi Santos on 09/06/2021.
//

import Foundation
import BeamCore

extension BeamTextEdit {

    private enum SlashMenuAction {

        // Node formatter
        case h1
        case h2
        case text
        case task
        case divider

        // Text Formatters
        case quote
        case bold
        case italic
        case strikethrough
        case underline
        case internalLink
        case date
        case meeting
        case blockRef
    }

    public func showSlashFormatter() {
        guard let node = focusedWidget as? TextNode else { return }
        dismissFormatterView(inlineFormatter)
        let targetRange = node.cursorPosition..<node.cursorPosition
        showSlashContextMenu(for: node, targetRange: targetRange)
    }

    private func showSlashContextMenu(for targetNode: TextNode?, targetRange: Range<Int>) {
        guard inlineFormatter?.isMouseInsideView != true else { return }
        clearDebounceTimer()
        guard let node = formatterTargetNode ?? (focusedWidget as? TextNode),
              isInlineFormatterHidden else { return }

        var atPoint = baseInlineFormatterPosition(for: node)
        atPoint.y += 8

        let items = getSlashMenuItems()
        let menuView = ContextMenuFormatterView(key: "SlashFormatter", items: items, handlesTyping: true)
        inlineFormatter = menuView
        prepareInlineFormatterWindowBeforeShowing(menuView, atPoint: atPoint)

        formatterTargetRange = targetRange
        formatterTargetNode = targetNode
        DispatchQueue.main.async {
            self.showOrHideInlineFormatter(isPresent: true)
        }
    }

    private func handleAction(_ action: SlashMenuAction) {
        guard let node = formatterTargetNode,
              let initialRange = formatterTargetRange,
              initialRange.lowerBound <= node.cursorPosition
              else { return }
        showOrHideInlineFormatter(isPresent: false)

        node.cmdManager.beginGroup(with: "Slash Menu Formatting")
        let range = initialRange.lowerBound..<node.cursorPosition
        node.cmdManager.deleteText(in: node, for: range)

        let (elementKind, attribute) = formattingElementAndAttribute(for: action, in: node)
        switch action {
        case .divider:
            insertDivider(in: node)
        case .internalLink:
            insertInternalLink(in: node, for: range)
        case .date:
            insertDate(in: node, for: range)
        case .meeting:
            insertMeetingSearch(in: node, for: range)
        case .blockRef:
            insertBlockRef(in: node, for: range)
        default:
            break
        }

        if attribute != nil || elementKind != nil {
            node.cmdManager.formatText(in: node, for: elementKind, with: attribute, for: initialRange, isActive: false)
        }
        node.cmdManager.endGroup()
    }

    private func getSlashMenuItems() -> [ContextMenuItem] {
        let action: (SlashMenuAction) -> Void = { [weak self] type in
            self?.handleAction(type)
        }
        var items = [
            ContextMenuItem(title: "Card Reference", subtitle: "@ or [[", icon: "field-card", action: { action(.internalLink) }),
            ContextMenuItem(title: "Todo", subtitle: "-[]", icon: "editor-task", action: { action(.task) }),
            ContextMenuItem(title: "Date Picker", subtitle: "", icon: "editor-calendar", action: { action(.date) }),
            ContextMenuItem.separator(),
            ContextMenuItem(title: "Bold", subtitle: "*", action: { action(.bold) }),
            ContextMenuItem(title: "Italic", subtitle: "**", action: { action(.italic) }),
            ContextMenuItem(title: "Strikethrough", subtitle: "~~", action: { action(.strikethrough) }),
            ContextMenuItem(title: "Underline", subtitle: "_", action: { action(.underline) }),
            ContextMenuItem(title: "Heading 1", subtitle: "#", action: { action(.h1) }),
            ContextMenuItem(title: "Heading 2", subtitle: "##", action: { action(.h2) }),
            ContextMenuItem(title: "Text", subtitle: "-", action: { action(.text) }),
            ContextMenuItem(title: "Divider", subtitle: "---", action: { action(.divider) })
        ]
        if data?.calendarManager.isConnected(calendarService: .googleCalendar) == true {
            items.insert(ContextMenuItem(title: "Meeting", subtitle: "", icon: "editor-calendar", action: { action(.meeting) }), at: 3)
        }
        return items
    }

    // MARK: - perform actions

    private func formattingElementAndAttribute(for action: SlashMenuAction,
                                               in node: TextNode) -> (ElementKind?, BeamText.Attribute?) {
        var attribute: BeamText.Attribute?
        var elementKind: ElementKind?
        switch action {
        case .bold:
            attribute = .strong
        case .italic:
            attribute = .emphasis
        case .strikethrough:
            attribute = .strikethrough
        case .underline:
            attribute = .underline
        case .h1:
            elementKind = .heading(1)
        case .h2:
            elementKind = .heading(2)
        case .quote:
            elementKind = .quote(1, node.text.text, node.text.text)
        case .task:
            elementKind = .check(false)
        case .text:
            elementKind = .bullet
            attribute = .none
        default:
            break
        }
        return (elementKind, attribute)
    }

    private func insertDivider(in node: TextNode) {
        // Divider node coming soon https://linear.app/beamapp/issue/BE-916/menu-divider
        let divider = BeamElement()
        divider.kind = .divider
        let parent = node.parent as? ElementNode ?? node
        node.cmdManager.insertElement(divider, inNode: parent, afterNode: node)
        let dividerNode = parent.nodeFor(divider)
        let emptyElement = BeamElement("")
        node.cmdManager.insertElement(emptyElement, inNode: parent, afterNode: dividerNode)
        if let emptyNode = parent.nodeFor(emptyElement) {
            node.cmdManager.focusElement(emptyNode, cursorPosition: 0)
        }
    }

    private func insertInternalLink(in node: TextNode, for range: Range<Int>) {
        node.cmdManager.insertText(BeamText(text: "@", attributes: []), in: node, at: range.lowerBound)
        node.cmdManager.focusElement(node, cursorPosition: range.lowerBound + 1)
        showCardReferenceFormatter(atPosition: node.cursorPosition, prefix: 1, suffix: 0)
    }

    private func insertBlockRef(in node: TextNode, for range: Range<Int>) {
        node.cmdManager.insertText(BeamText(text: "(())", attributes: []), in: node, at: range.lowerBound)
        node.cmdManager.focusElement(node, cursorPosition: range.lowerBound + 2)
        showCardReferenceFormatter(atPosition: node.cursorPosition, searchCardContent: true)
        updateInlineFormatterView(isDragged: false, isKeyEvent: true)
    }
}

// MARK: - Date Picker
extension BeamTextEdit {
    private func insertDate(in node: TextNode, for range: Range<Int>) {
        let placeholderText = BeamText(text: "@date ", attributes: [Self.formatterPlaceholderAttribute])
        node.root?.insertText(text: placeholderText, replacementRange: nil)
        var editableRange = range.lowerBound..<range.lowerBound+placeholderText.count
        var selectedDate: Date?

        let calendarPicker = CalendarPickerFormatterView()
        calendarPicker.onDateChange = { [weak node, weak self] date in
            guard let node = node else { return }
            selectedDate = date
            let text = BeamDate.journalNoteTitle(for: date)
            let dateText = BeamText(text: text, attributes: [.internalLink(UUID.null)])
            node.root?.insertText(text: dateText, replacementRange: editableRange)
            editableRange = editableRange.lowerBound..<(editableRange.lowerBound+dateText.count)
            node.focus(position: editableRange.upperBound)
            self?.hideInlineFormatter()
        }
        calendarPicker.onDismiss = { [weak node, weak self] _ in
            guard let node = node else { return }
            self?.onFinishPickingDate(selectedDate, in: node, for: editableRange, placeholderText: placeholderText)
        }
        inlineFormatter = calendarPicker
        prepareInlineFormatterWindowBeforeShowing(calendarPicker, atPoint: .zero)
        moveInlineFormatterAtSelection(below: true)
        node.focus(position: editableRange.upperBound - 1)
        DispatchQueue.main.async {
            self.showOrHideInlineFormatter(isPresent: true)
        }
    }

    private func onFinishPickingDate(_ date: Date?, in node: TextNode, for range: Range<Int>, placeholderText: BeamText) {
        guard let date = date else {
            cleanupPickerPlaceholder(in: node, for: range, placeholderText: placeholderText)
            return
        }
        let title = BeamDate.journalNoteTitle(for: date)
        let note = BeamNote.fetchOrCreateJournalNote(date: date)
        let dateText = BeamText(text: title, attributes: [.internalLink(note.id)])
        node.cmdManager.replaceText(in: node, for: range, with: dateText)
    }

    private func cleanupPickerPlaceholder(in node: TextNode, for range: Range<Int>, placeholderText: BeamText) {
        let decoAttribute = placeholderText.ranges.first?.attributes.first
        var rangesToDelete = [BeamText.Range]()
        var rangesToClean = [BeamText.Range]()
        node.cmdManager.beginGroup(with: "Picker placeholder cleanup")
        let decoRanges = node.text.ranges.filter { $0.attributes.first?.rawValue == decoAttribute?.rawValue }
        decoRanges.forEach { r in
            if decoRanges.count == 1 || r.position >= range.lowerBound && r.end < range.upperBound {
                rangesToDelete.append(r)
            } else {
                rangesToClean.append(r)
            }
        }
        let cursorPosition = max(0, node.cursorPosition - (placeholderText.count - 1))
        rangesToClean.forEach { r in
            node.cmdManager.formatText(in: node, for: nil, with: r.attributes.first, for: r.position..<r.end, isActive: true)
        }
        rangesToDelete.forEach { r in
            node.cmdManager.deleteText(in: node, for: r.position..<r.end)
        }
        node.focus(position: cursorPosition)
        node.cmdManager.endGroup()
    }
}

// MARK: - Meeting Picker
extension BeamTextEdit {
    private func insertMeetingSearch(in node: TextNode, for range: Range<Int>) {
        guard let calendarManager = data?.calendarManager else { return }
        let placeholderText = BeamText(text: "/", attributes: [Self.formatterPlaceholderAttribute])
        let cursorPosition = range.lowerBound
        node.root?.cmdManager.insertText(placeholderText, in: node, at: cursorPosition)
        let endPlaceholderCursorPosition = cursorPosition + placeholderText.count
        let meetingPicker = MeetingFormatterView(calendarManager: calendarManager, todaysNote: data?.todaysNote)
        meetingPicker.onFinish = { [weak node, weak self] meeting in
            guard let node = node, let lowerBound = self?.formatterTargetRange?.lowerBound else { return }
            let editedRange = lowerBound <= cursorPosition ? lowerBound..<endPlaceholderCursorPosition : cursorPosition..<endPlaceholderCursorPosition
            guard let meeting = meeting else {
                self?.cleanupPickerPlaceholder(in: node, for: editedRange, placeholderText: placeholderText)
                return
            }

            let model = MeetingModalView.ViewModel(meetingName: meeting.name, startTime: meeting.startTime,
                                                   attendees: meeting.attendees,
                                                   onFinish: { [weak self, weak node] meeting in
                                                    guard let node = node else { return }
                                                    self?.onFinishSelectingMeeting(in: node, meeting: meeting, range: editedRange)
                                                   })
            self?.state?.overlayViewModel.presentModal(MeetingModalView(viewModel: model))
            self?.hideInlineFormatter()
        }

        var atPoint = baseInlineFormatterPosition(for: node)
        atPoint.y -= 8
        inlineFormatter = meetingPicker
        formatterTargetNode = node
        formatterTargetRange = endPlaceholderCursorPosition..<endPlaceholderCursorPosition
        node.focus(position: endPlaceholderCursorPosition)
        prepareInlineFormatterWindowBeforeShowing(meetingPicker, atPoint: atPoint)
        DispatchQueue.main.async {
            self.showOrHideInlineFormatter(isPresent: true)
        }
    }

    private func onFinishSelectingMeeting(in node: TextNode, meeting: Meeting?, range: Range<Int>) {
        state?.overlayViewModel.dismissCurrentModal()
        if let editor = rootNode?.editor {
            editor.window?.makeFirstResponder(editor)
        }
        guard let meeting = meeting else {
            node.cmdManager.deleteText(in: node, for: range)
            return
        }
        let text = meeting.buildBeamText()
        let cmdManager = node.cmdManager
        cmdManager.beginGroup(with: "Insert Meeting")
        defer { cmdManager.endGroup() }
        let meetingElement = BeamElement(text)
        let emptyChild = BeamElement("")
        meetingElement.addChild(emptyChild)
        if let parentNode = (node.parent as? ElementNode) {
            cmdManager.insertElement(meetingElement, inNode: parentNode, afterNode: node)
            if let emptyNode = parentNode.nodeFor(meetingElement)?.nodeFor(emptyChild) {
                cmdManager.focusElement(emptyNode, cursorPosition: 0)
            }
            cmdManager.deleteElement(for: node)
        }
    }
}
