//
//  NoteHeaderView.swift
//  Beam
//
//  Created by Remi Santos on 10/05/2021.
//

import SwiftUI
import BeamCore

struct NoteHeaderView: View {

    private static let leadingPadding: CGFloat = 18
    static let topPadding: CGFloat = PreferencesManager.editorHeaderTopPadding
    @ObservedObject var model: NoteHeaderView.ViewModel

    private let errorColor = BeamColor.Shiraz
    private var textColor: BeamColor {
        model.isTitleTaken ? errorColor : BeamColor.Generic.text
    }
    private static var dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM dd, yyyy"
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
                              multiline: true,
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
        .accessibility(identifier: "Card's title")
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
        Text("\(BeamDate.journalNoteTitle(for: model.note.creationDate))")
            .font(BeamFont.medium(size: 12).swiftUI)
            .foregroundColor(BeamColor.Generic.placeholder.swiftUI)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: BeamSpacing._40) {
                dateView
                    .opacity(model.note.type.isJournal ? 0 : 1)
                    .offset(x: 1, y: 0) // compensate for different font size leading alignment
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
        .padding(.leading, Self.leadingPadding)
    }
}

extension NoteHeaderView {
    class ViewModel: ObservableObject {
        @Published var note: BeamNote
        private weak var state: BeamState?

        @Published fileprivate var titleText: String
        @Published fileprivate var titleSelectedRange: Range<Int>?

        @Published fileprivate var isEditingTitle = false
        @Published fileprivate var isTitleTaken = false
        @Published fileprivate var wiggleValue = CGFloat(0)

        private var documentManager: DocumentManager
        fileprivate var canEditTitle: Bool {
            !note.type.isJournal
        }

        init(note: BeamNote, state: BeamState? = nil, documentManager: DocumentManager) {
            self.note = note
            self.state = state
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
            guard !newTitle.isEmpty, newTitle != note.title, !isTitleTaken, canEditTitle else {
                if fromTextField && isTitleTaken {
                    wiggleValue += 1
                } else {
                    resetEditingState()
                }
                return
            }
            note.updateTitle(newTitle, documentManager: documentManager)
            isEditingTitle = false
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
                    ContextMenuItem(title: "Copy Link", action: copyLink),
                    ContextMenuItem(title: "Invite...", action: nil),
                    ContextMenuItem.separator()
                ])
            }
            items.append(contentsOf: [
                ContextMenuItem(title: isNotePublic ? "Unpublish" : "Publish", action: togglePublish),
                ContextMenuItem.separator()
            ])
            items.append(ContextMenuItem(title: "Rename", action: canEditTitle ? focusTitle : nil))

            items.append(contentsOf: [
                ContextMenuItem.separator(),
                ContextMenuItem(title: "Delete", action: onDelete)
            ])

            let menuView = ContextMenuFormatterView(items: items, direction: .bottom) {
                CustomPopoverPresenter.shared.dismissMenu()
            }
            CustomPopoverPresenter.shared.presentMenu(menuView, atPoint: at)
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

        private func copyLink() {
            let sharingUtils = BeamNoteSharingUtils(note: note)
            sharingUtils.copyLinkToClipboard { [weak self] _ in
                self?.state?.overlayViewModel.present(text: "Link Copied", icon: "tooltip-mark", alignment: .bottomLeading)
            }
        }

        private func togglePublish() {
            let sharingUtils = BeamNoteSharingUtils(note: note)
            let isPublic = note.isPublic
            guard isPublic || sharingUtils.canMakePublic else {
                state?.overlayViewModel.present(text: "You need to be logged in", icon: "status-private", alignment: .bottomLeading)
                return
            }
            sharingUtils.makeNotePublic(!isPublic, documentManager: documentManager) { [weak self] _ in
                if self?.note.isPublic == true {
                    self?.copyLink()
                }
            }
        }

        private func onDelete() {
            let cmdManager = CommandManagerAsync<DocumentManager>()
            cmdManager.deleteDocuments(ids: [note.id], in: documentManager)
            guard let state = state else { return }
            DispatchQueue.main.async {
                if state.canGoBack {
                    state.goBack()
                } else {
                    state.navigateToJournal(note: nil)
                }
                state.backForwardList.clearForward()
                state.updateCanGoBackForward()
            }
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
