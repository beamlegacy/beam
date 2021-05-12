//
//  NoteHeaderView.swift
//  Beam
//
//  Created by Remi Santos on 10/05/2021.
//

import SwiftUI
import BeamCore

struct NoteHeaderView: View {

    static let topPadding: CGFloat = 60

    var note: BeamNote
    var documentManager: DocumentManager

    @State private var titleValue = ""
    @State private var isEditingTitle = false
    @State private var isTitleTaken = false
    @State private var isLoading = false
    @State private var hasIncorrectChars = false
    @State private var titleSelectedRange: Range<Int>?

    private var canEditTitle: Bool {
        note.type != .journal
    }
    private let errorColor = BeamColor.Shiraz.swiftUI
    // TODO: Move to beamnote method from https://gitlab.com/beamgroup/beam/-/merge_requests/560
    private let rejectedCharsRegex = "[._!?\"#%&,:;<>=@{}~$\\(\\)\\*\\+\\[\\]\\^\\|\\/\\\\]"
    private static var dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt
    }()

    private func incorrectCharRanges(in text: String) -> [Range<String.Index>] {
        if let regex = try? NSRegularExpression(pattern: rejectedCharsRegex, options: []) {
            let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
            return results.map { checkResult in
                text.index(at: checkResult.range.lowerBound)..<text.index(at: checkResult.range.upperBound)
            }
        }
        return []
    }

    private var titleView: some View {
        ZStack(alignment: .leading) {
            if canEditTitle {
                BeamTextField(text: $titleValue,
                              isEditing: $isEditingTitle,
                              placeholder: "Card's title",
                              font: BeamFont.medium(size: 26).nsFont,
                              // we use a transparent text field to have a styled text above.
                              textColor: BeamColor.Generic.text.nsColor.withAlphaComponent(0),
                              placeholderColor: BeamColor.Generic.placeholder.nsColor,
                              selectedRange: titleSelectedRange,
                              onTextChanged: onTitleChanged,
                              onCommit: { _ in
                                renameCard()
                              })
            }
            StyledText(verbatim: titleValue)
                .style(.foregroundColor(errorColor), ranges: incorrectCharRanges)
                .lineLimit(1) // TODO: Support multiline - https://linear.app/beamapp/issue/BE-799/renaming-cards-multiline-support
                .font(BeamFont.medium(size: 26).swiftUI)
                .foregroundColor(isTitleTaken ? errorColor : BeamColor.Generic.text.swiftUI)
                .gesture(TapGesture().onEnded {
                    titleSelectedRange = nil
                    // wait to see if double tap happened
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        guard !isEditingTitle else { return }
                        focusTitle()
                    }
                })
                .simultaneousGesture(TapGesture(count: 2).onEnded {
                    titleSelectedRange = titleValue.wholeRange
                    isEditingTitle = true
                })
                .allowsHitTesting(!isEditingTitle)
        }
        .animation(nil)
        .onAppear {
            titleValue = note.title
        }
        .id(note.id) // make sure we reset view when changing note
    }

    private var subtitleInfoView: some View {
        Group {
            if hasIncorrectChars {
                Text("A card’s title cannot contain ")
                + Text("special characters")
                    .foregroundColor(errorColor)
            } else if isTitleTaken {
                Text("This card’s title ")
                + Text("already exists")
                    .foregroundColor(errorColor)
                + Text(" in your knowledge base")
            }
        }
        .font(BeamFont.medium(size: 10).swiftUI)
        .foregroundColor(BeamColor.Generic.placeholder.swiftUI)
        .transition(AnyTransition.opacity.animation(Animation.easeInOut(duration: 0.15)))
    }

    private var dateView: some View {
        Text("\(Self.dateFormatter.string(from: note.creationDate))")
            .font(BeamFont.medium(size: 12).swiftUI)
            .foregroundColor(BeamColor.Generic.placeholder.swiftUI)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: BeamSpacing._60) {
                dateView
                HStack {
                    titleView
                    Spacer()
                    GeometryReader { geometry in
                        ButtonLabel(icon: "editor-options") {
                            let frame = geometry.frame(in: .global)
                            showContextualMenu(at: CGPoint(x: frame.maxX - 26, y: frame.maxY - 26))
                        }
                    }
                    .frame(width: 26, height: 26)
                }
                subtitleInfoView
            }
        }
        .padding(.top, Self.topPadding)
        .padding(.leading, 20)
    }

    private func onTitleChanged(_ text: String) {
        titleSelectedRange = nil
        let incorrectRanges = incorrectCharRanges(in: text)
        let newTitle = formatToValidTitle(titleValue)
        let existingNote = documentManager.loadDocumentByTitle(title: newTitle)

        hasIncorrectChars = !incorrectRanges.isEmpty
        if existingNote != nil, existingNote?.id != note.id {
            isTitleTaken = true
        } else {
            isTitleTaken = false
        }
    }

    private func resetEditingState() {
        titleValue = note.title
        isEditingTitle = false
        isTitleTaken = false
        hasIncorrectChars = false
    }

    // TODO: Replace by beamnote method from https://gitlab.com/beamgroup/beam/-/merge_requests/560
    private func formatToValidTitle(_ title: String) -> String {
        var result = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let regex = try? NSRegularExpression(pattern: rejectedCharsRegex, options: []) {
            let mutableString = NSMutableString(string: result)
            regex.replaceMatches(in: mutableString, options: [], range: NSRange(location: 0, length: mutableString.length), withTemplate: "")
            result = String(mutableString)
        }
        return result
    }

    private func renameCard() {
        let newTitle = formatToValidTitle(titleValue)
        guard !newTitle.isEmpty, newTitle != note.title, !isLoading, !hasIncorrectChars, !isTitleTaken, canEditTitle else {
            resetEditingState()
            return
        }
        isLoading = true
        note.updateTitle(newTitle, documentManager: documentManager) { _ in
            DispatchQueue.main.async {
                self.isEditingTitle = false
                self.isLoading = false
            }
        }
    }

    private func focusTitle() {
        titleSelectedRange = titleValue.wholeRange.upperBound..<titleValue.wholeRange.upperBound
        isEditingTitle = true
    }

    private func showContextualMenu(at: CGPoint) {
        var items: [[ContextMenuItem]] = []
        if note.isPublic {
            items.append([
                ContextMenuItem(title: "Copy Link", action: nil),
                ContextMenuItem(title: "Invite...", action: nil)
            ])
        }
        items.append([ContextMenuItem(title: note.isPublic ? "Unpublish" : "Publish", action: nil)])
        var thirdGroup = [
            ContextMenuItem(title: "Favorite", action: nil),
            ContextMenuItem(title: "Export", action: nil)
        ]
        if canEditTitle {
            thirdGroup.insert(ContextMenuItem(title: "Rename", action: focusTitle), at: 0)
        }
        items.append(thirdGroup)
        items.append([ContextMenuItem(title: "Delete", action: nil)])

        let menuView = ContextMenuFormatterView(items: items, direction: .bottom) {
            ContextMenuPresenter.shared.dismissMenu()
        }
        ContextMenuPresenter.shared.presentMenu(menuView, atPoint: at)
    }
}

// custom initializer for preview
fileprivate extension NoteHeaderView {
    init(title: String, documentManager: DocumentManager, incorrect: Bool = false, taken: Bool = false) {
        self.note = BeamNote(title: title)
        self.documentManager = documentManager
        _hasIncorrectChars = State(initialValue: incorrect)
        _isTitleTaken = State(initialValue: taken)
    }
}

struct NoteHeaderView_Previews: PreviewProvider {
    static let documentManager = DocumentManager()
    static var previews: some View {
        VStack {
            NoteHeaderView(title: "My note title", documentManager: documentManager)
            NoteHeaderView(title: "What? I can't do-this?", documentManager: documentManager, incorrect: true)
            NoteHeaderView(title: "Taken title", documentManager: documentManager, taken: true)
        }
        .padding()
        .background(BeamColor.Generic.background.swiftUI)
    }
}
