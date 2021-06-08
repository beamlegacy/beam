//
//  NoteHeaderView.swift
//  Beam
//
//  Created by Remi Santos on 10/05/2021.
//

import SwiftUI
import BeamCore

struct NoteHeaderView: View {

    static let topPadding: CGFloat = 104
    @ObservedObject var model: NoteHeaderView.ViewModel

    private let errorColor = BeamColor.Shiraz
    private var textColor: BeamColor {
        model.isTitleTaken ? errorColor : BeamColor.Generic.text
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
            if model.canEditTitle {
                BeamTextField(text: $model.titleText,
                              isEditing: $model.isEditingTitle,
                              placeholder: "Card's title",
                              font: BeamFont.medium(size: 26).nsFont,
                              textColor: textColor.nsColor,
                              placeholderColor: BeamColor.Generic.placeholder.nsColor,
                              selectedRange: model.titleSelectedRange,
                              onTextChanged: model.textFieldDidChange,
                              onCommit: { _ in
                                model.commitRenameCard(fromTextField: true)
                              }, onEscape: {
                                model.commitRenameCard(fromTextField: true)
                              }, onStopEditing: {
                                model.commitRenameCard(fromTextField: true)
                              })
                    .allowsHitTesting(model.isEditingTitle)
            } else {
                Text(model.titleText)
                    .lineLimit(2)
                    .font(BeamFont.medium(size: 26).swiftUI)
                    .foregroundColor(textColor.swiftUI)
            }
        }
        .contentShape(Rectangle())
        .gesture(TapGesture().onEnded(model.onTap))
        .simultaneousGesture(TapGesture(count: 2).onEnded(model.onDoubleTap))
        .animation(nil)
        .wiggleEffect(animatableValue: model.wiggleValue)
        .animation(model.wiggleValue > 0 ? .easeInOut(duration: 0.3) : nil)
        // force reloading the view on note change to clean up text states
        // and enables appear/disappear events between notes
        .id(model.note)
        .onDisappear {
            model.commitRenameCard(fromTextField: false)
        }
    }

    private var subtitleInfoView: some View {
        Group {
            if model.isTitleTaken {
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
        Text("\(Self.dateFormatter.string(from: model.note.creationDate))")
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
                            model.showContextualMenu(at: CGPoint(x: frame.maxX - 26, y: frame.maxY - 26))
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
}

extension NoteHeaderView {
    class ViewModel: ObservableObject {
        @Published var note: BeamNote

        @Published fileprivate var titleText: String
        @Published fileprivate var titleSelectedRange: Range<Int>?

        @Published fileprivate var isEditingTitle = false
        @Published fileprivate var isTitleTaken = false
        @Published fileprivate var isLoading = false
        @Published fileprivate var wiggleValue = CGFloat(0)

        private var documentManager: DocumentManager
        fileprivate var canEditTitle: Bool {
            note.type != .journal
        }

        init(note: BeamNote, documentManager: DocumentManager) {
            self.note = note
            self.documentManager = documentManager
            self.titleText = note.title
        }

        func textFieldDidChange(_ text: String) {
            titleSelectedRange = nil
            let newTitle = formatToValidTitle(titleText)
            let existingNote = documentManager.loadDocumentByTitle(title: newTitle)
            self.isTitleTaken = existingNote != nil && existingNote?.id != note.id
        }

        func resetEditingState() {
            titleText = note.title
            isEditingTitle = false
            isTitleTaken = false
            wiggleValue = 0
        }

        func formatToValidTitle(_ title: String) -> String {
            return BeamNote.validTitle(fromTitle: title)
        }

        func commitRenameCard(fromTextField: Bool) {
            let newTitle = formatToValidTitle(titleText)
            guard !newTitle.isEmpty, newTitle != note.title, !isLoading, !isTitleTaken, canEditTitle else {
                if fromTextField && isTitleTaken {
                    wiggleValue += 1
                } else {
                    resetEditingState()
                }
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

        func focusTitle() {
            titleSelectedRange = titleText.wholeRange.upperBound..<titleText.wholeRange.upperBound
            isEditingTitle = true
        }

        func showContextualMenu(at: CGPoint) {
            var items: [ContextMenuItem] = []
            let isNotePublic = note.isPublic
            if isNotePublic {
                items.append(contentsOf: [
                    ContextMenuItem(title: "Copy Link", action: nil),
                    ContextMenuItem(title: "Invite...", action: nil),
                    ContextMenuItem.separator()
                ])
            }
            items.append(ContextMenuItem(title: isNotePublic ? "Unpublish" : "Publish", action: nil))
            var thirdGroup = [
                ContextMenuItem.separator(),
                ContextMenuItem(title: "Favorite", action: nil),
                ContextMenuItem(title: "Export", action: nil)
            ]
            if canEditTitle {
                thirdGroup.insert(ContextMenuItem(title: "Rename", action: focusTitle), at: 1)
            }
            items.append(contentsOf: thirdGroup)
            
            items.append(contentsOf: [
                ContextMenuItem.separator(),
                ContextMenuItem(title: "Delete", action: nil)
            ])

            let menuView = ContextMenuFormatterView(items: items, direction: .bottom) {
                ContextMenuPresenter.shared.dismissMenu()
            }
            ContextMenuPresenter.shared.presentMenu(menuView, atPoint: at)
        }

        func onTap() {
            guard canEditTitle else { return }
            titleSelectedRange = nil
            // wait to see if double tap happened
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                guard !self.isEditingTitle else { return }
                self.focusTitle()
            }
        }

        func onDoubleTap() {
            guard canEditTitle else { return }
            titleSelectedRange = titleText.wholeRange
            isEditingTitle = true
        }
    }
}

struct NoteHeaderView_Previews: PreviewProvider {
    static let documentManager = DocumentManager()
    static var classicModel: NoteHeaderView.ViewModel {
        NoteHeaderView.ViewModel(note: BeamNote(title: "My note title"), documentManager: documentManager)
    }
    static var titleTakenModel: NoteHeaderView.ViewModel {
        let model = NoteHeaderView.ViewModel(note: BeamNote(title: "Taken Title"), documentManager: documentManager)
        model.isTitleTaken = true
        return model
    }
    static var previews: some View {
        VStack {
            NoteHeaderView(model: classicModel)
            NoteHeaderView(model: titleTakenModel)
        }
        .padding()
        .background(BeamColor.Generic.background.swiftUI)
    }
}
