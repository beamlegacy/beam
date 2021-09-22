//
//  NoteHeaderView.swift
//  Beam
//
//  Created by Remi Santos on 10/05/2021.
//

import SwiftUI
import BeamCore
import Combine

struct NoteHeaderView: View {

    private static let leadingPadding: CGFloat = 18
    static let topPadding: CGFloat = PreferencesManager.editorHeaderTopPadding
    @ObservedObject var model: NoteHeaderView.ViewModel

    var topPadding: CGFloat = Self.topPadding
    private let errorColor = BeamColor.Shiraz
    private var textColor: BeamColor {
        model.isTitleTaken ? errorColor : BeamColor.Generic.text
    }

    @State private var publishShowError = false
    @State private var hoveringLinkButton = false

    private var copyLinkView: some View {
        let justCopiedLink = model.justCopiedLinkFrom == .fromLinkIcon
        let transition = AnyTransition.asymmetric(insertion: AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.2)),
                                                  removal: AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.05)))
        return ButtonLabel(icon: "editor-url_link", customStyle: .tinyIconStyle) {
            model.copyLink(source: .fromLinkIcon)
        }
        .overlay(
            ZStack {
                if justCopiedLink {
                    Tooltip(title: "Link Copied")
                        .fixedSize().offset(x: -18, y: 0)
                        .transition(transition)
                } else if hoveringLinkButton {
                    Tooltip(title: "Copy Link")
                        .fixedSize().offset(x: -18, y: 0)
                        .transition(transition)
                }
            }, alignment: .trailing)
        .onHover { hoveringLinkButton = $0 }
        .transition(AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.15)))
        .offset(x: -20, y: 0)
    }

    private var titleView: some View {
        ZStack(alignment: .leading) {
            // TODO: Support multiline editing
            // https://linear.app/beamapp/issue/BE-799/renaming-cards-multiline-support
            if model.canEditTitle {
                BeamTextField(text: $model.titleText,
                              isEditing: $model.isEditingTitle,
                              placeholder: "Card's title",
                              font: BeamFont.medium(size: PreferencesManager.editorCardTitleFontSize).nsFont,
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
                    .font(BeamFont.medium(size: PreferencesManager.editorCardTitleFontSize).swiftUI)
                    .foregroundColor(textColor.swiftUI)
            }
        }
        .contentShape(Rectangle())
        .gesture(TapGesture().onEnded(model.onTap))
        .simultaneousGesture(TapGesture(count: 2).onEnded(model.onDoubleTap))
        .animation(nil)
        .wiggleEffect(animatableValue: model.wiggleValue)
        .animation(model.wiggleValue > 0 ? BeamAnimation.easeInOut(duration: 0.3) : nil)
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
        .transition(AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.15)))
    }

    private var dateView: some View {
        Text("\(BeamDate.journalNoteTitle(for: model.note.creationDate))")
            .font(BeamFont.medium(size: 12).swiftUI)
            .foregroundColor(BeamColor.Generic.placeholder.swiftUI)
    }

    private var actionsView: some View {
        HStack(spacing: BeamSpacing._100) {
            NoteHeaderPublishButton(publishState: model.publishState,
                                    justCopiedLink: model.justCopiedLinkFrom == .fromPublishButton,
                                    showError: publishShowError,
                                    action: {
                                        let canPerform = model.togglePublish()
                                        if !canPerform {
                                            publishShowError = true
                                            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .seconds(2))) {
                                                publishShowError = false
                                            }
                                        }
                                    })

//            Feature not available yet.
//            ButtonLabel(icon: "editor-sources", state: .disabled)

            ButtonLabel(icon: "editor-delete", action: model.promptConfirmDelete)
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: BeamSpacing._40) {
                dateView
                    .opacity(model.note.type.isJournal ? 0 : 1)
                    .offset(x: 1, y: 0) // compensate for different font size leading alignment
                HStack {
                    titleView
                        .overlay(model.publishState != .isPublic ? nil : copyLinkView, alignment: .leading)
                    Spacer()
                    actionsView
                }
                subtitleInfoView
            }
        }
        .padding(.top, self.topPadding)
        .padding(.leading, Self.leadingPadding)
    }
}

extension NoteHeaderView {
    fileprivate enum CopyLinkSource {
        case fromLinkIcon
        case fromPublishButton
    }

    class ViewModel: ObservableObject {
        @Published var note: BeamNote
        private weak var state: BeamState?

        // title editing
        @Published fileprivate var titleText: String
        @Published fileprivate var titleSelectedRange: Range<Int>?
        @Published fileprivate var isEditingTitle = false
        @Published fileprivate var isTitleTaken = false
        @Published fileprivate var wiggleValue = CGFloat(0)

        // publishing
        @Published fileprivate var publishState: NoteHeaderPublishButton.PublishButtonState = .isPrivate
        @Published fileprivate var justCopiedLinkFrom: NoteHeaderView.CopyLinkSource?
        private var publishingDispatchItem: DispatchWorkItem?
        private var copyLinkDispatchItem: DispatchWorkItem?
        private var noteObserver: AnyCancellable?

        private var documentManager: DocumentManager
        fileprivate var canEditTitle: Bool {
            !note.type.isJournal
        }

        init(note: BeamNote, state: BeamState? = nil, documentManager: DocumentManager) {
            self.note = note
            self.state = state
            self.documentManager = documentManager
            self.titleText = note.title
            self.publishState = note.isPublic ? .isPublic : .isPrivate
            self.noteObserver = note.$isPublic.dropFirst().removeDuplicates().sink { [weak self] newValue in
                guard self?.publishState == .isPublic || self?.publishState == .isPrivate else { return }
                self?.publishState = newValue ? .isPublic : .isPrivate
            }
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

        // MARK: Link
        fileprivate func copyLink(source: NoteHeaderView.CopyLinkSource) {
            let sharingUtils = BeamNoteSharingUtils(note: note)
            sharingUtils.copyLinkToClipboard { [weak self] _ in
                self?.justCopiedLinkFrom = source
                self?.copyLinkDispatchItem?.cancel()
                let workItem = DispatchWorkItem { [weak self] in
                    self?.justCopiedLinkFrom = nil
                }
                self?.copyLinkDispatchItem = workItem
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .seconds(2)), execute: workItem)
            }
        }

        // MARK: Publishing

        /// returns true if user is allowed to perform the action
        func togglePublish() -> Bool {
            guard ![.publishing, .unpublishing].contains(publishState) else { return true }
            let sharingUtils = BeamNoteSharingUtils(note: note)
            let isPublic = note.isPublic
            guard isPublic || sharingUtils.canMakePublic else {
                return false
            }
            if !isPublic {
                publishState = .publishing
                sharingUtils.makeNotePublic(true, documentManager: documentManager) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.noteBecamePublic(true)
                        self?.copyLink(source: .fromPublishButton)
                    }
                }
            } else {
                publishState = .unpublishing
                promptConfirmUnpublish()
            }
            return true
        }

        private func noteBecamePublic(_ value: Bool, debounce: Bool = true) {
            publishingDispatchItem?.cancel()
            if debounce {
                publishState = value ? .justPublished : .justUnpublished
                let workItem = DispatchWorkItem { [weak self] in
                    self?.publishState = value ? .isPublic : .isPrivate
                }
                publishingDispatchItem = workItem
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .seconds(2)), execute: workItem)
            } else {
                publishState = value ? .isPublic : .isPrivate
            }
        }

        private func promptConfirmUnpublish() {
            let alert = NSAlert()
            alert.messageText = "Are you sure you want to unpublish the card \"\(note.title)\"?"
            alert.informativeText = "Others will no longer have access to this card."
            alert.addButton(withTitle: "Unpublish")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .warning
            guard let window = AppDelegate.main.window else { return }
            alert.beginSheetModal(for: window) { [weak self] response in
                guard let self = self else { return }
                guard response == .alertFirstButtonReturn else {
                    self.publishState = self.note.isPublic == true ? .isPublic : .isPrivate
                    return
                }
                BeamNoteSharingUtils(note: self.note).makeNotePublic(false, documentManager: self.documentManager) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.noteBecamePublic(false)
                    }
                }
            }
        }

        // MARK: Delete
        private func confirmedDelete() {
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

        func promptConfirmDelete() {
            let alert = NSAlert()
            alert.messageText = "Are you sure you want to delete the card \"\(note.title)\"?"
            alert.informativeText = "This cannot be undone."
            alert.addButton(withTitle: "Delete...")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .warning
            guard let window = AppDelegate.main.window else { return }
            alert.beginSheetModal(for: window) { [weak self] response in
                guard response == .alertFirstButtonReturn, let self = self else { return }
                self.confirmedDelete()
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
            NoteHeaderView(model: classicModel, topPadding: 20)
            NoteHeaderView(model: titleTakenModel, topPadding: 60)
        }
        .border(Color.green)
        .padding(.vertical)
        .padding(.horizontal, 100)
        .border(Color.red)
        .background(BeamColor.Generic.background.swiftUI)
    }
}
