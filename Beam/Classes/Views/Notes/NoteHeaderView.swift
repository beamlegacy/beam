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
    @State private var titleSelectedRange: Range<Int>?

    private var canEditTitle: Bool {
        note.type != .journal
    }
    private let errorColor = BeamColor.Shiraz
    private var textColor: BeamColor {
        isTitleTaken ? errorColor : BeamColor.Generic.text
    }
    private static var dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt
    }()


    private var titleView: some View {
        ZStack(alignment: .leading) {
            // TODO: Support multiline editing
            // https://linear.app/beamapp/issue/BE-799/renaming-cards-multiline-support
            if canEditTitle {
                BeamTextField(text: $titleValue,
                              isEditing: $isEditingTitle,
                              placeholder: "Card's title",
                              font: BeamFont.medium(size: 26).nsFont,
                              textColor: textColor.nsColor,
                              placeholderColor: BeamColor.Generic.placeholder.nsColor,
                              selectedRange: titleSelectedRange,
                              onTextChanged: onTitleChanged,
                              onCommit: { _ in
                                renameCard()
                              })
                    .allowsHitTesting(isEditingTitle)
            } else {
                Text(titleValue)
                    .lineLimit(2)
                    .font(BeamFont.medium(size: 26).swiftUI)
                    .foregroundColor(textColor.swiftUI)
            }
        }
        .contentShape(Rectangle())
        .gesture(TapGesture().onEnded {
            guard canEditTitle else { return }
            titleSelectedRange = nil
            // wait to see if double tap happened
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                guard !isEditingTitle else { return }
                focusTitle()
            }
        })
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            guard canEditTitle else { return }
            titleSelectedRange = titleValue.wholeRange
            isEditingTitle = true
        })
        .animation(nil)
        .onAppear {
            titleValue = note.title
        }
        .id(note.id) // make sure we reset view when changing note
    }

    private var subtitleInfoView: some View {
        Group {
            if isTitleTaken {
                Text("This card’s title ")
                + Text("already exists")
                    .foregroundColor(errorColor.swiftUI)
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
                if isEditingTitle {
                    subtitleInfoView
                }
            }
        }
        .padding(.top, Self.topPadding)
        .padding(.leading, 20)
    }

    private func onTitleChanged(_ text: String) {
        titleSelectedRange = nil
        let newTitle = formatToValidTitle(titleValue)
        let existingNote = documentManager.loadDocumentByTitle(title: newTitle)

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
    }

    private func formatToValidTitle(_ title: String) -> String {
        return BeamNote.validTitle(fromTitle: title)
    }

    private func renameCard() {
        let newTitle = formatToValidTitle(titleValue)
        guard !newTitle.isEmpty, newTitle != note.title, !isLoading, !isTitleTaken, canEditTitle else {
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
    init(title: String, documentManager: DocumentManager, taken: Bool = false) {
        self.note = BeamNote(title: title)
        self.documentManager = documentManager
        _isTitleTaken = State(initialValue: taken)
    }
}

struct NoteHeaderView_Previews: PreviewProvider {
    static let documentManager = DocumentManager()
    static var previews: some View {
        VStack {
            NoteHeaderView(title: "My note title", documentManager: documentManager)
            NoteHeaderView(title: "Taken title", documentManager: documentManager, taken: true)
        }
        .padding()
        .background(BeamColor.Generic.background.swiftUI)
    }
}
