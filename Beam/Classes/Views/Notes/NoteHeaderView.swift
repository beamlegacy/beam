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

    @State private var publishShowError: NoteHeaderPublishButton.ErrorMessage?
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
        Text("\(BeamDate.journalNoteTitle(for: model.note?.creationDate ?? BeamDate.now))")
            .font(BeamFont.medium(size: 12).swiftUI)
            .foregroundColor(BeamColor.Generic.placeholder.swiftUI)
    }

    private var actionsView: some View {
        HStack(spacing: BeamSpacing._100) {
            NoteHeaderPublishButton(publishState: model.publishState,
                                    justCopiedLink: model.justCopiedLinkFrom == .fromPublishButton,
                                    error: publishShowError,
                                    action: {
                                        let canPerform = model.togglePublish { result in
                                            switch result {
                                            case .success(_):
                                                break
                                            case .failure(let error):
                                                handlePublicationError(error: error)
                                            }
                                        }
                                        if !canPerform {
                                            showPublicationError(error: .loggedOut)
                                        }
                                    })
//            Feature not available yet.
//            ButtonLabel(icon: "editor-sources", state: .disabled)
            ButtonLabel(icon: "editor-delete", action: model.promptConfirmDelete)
        }
    }

    private func handlePublicationError(error: Error) {
        if let error = error as? RestAPIServer.Error {
            switch error {
            case .noUsername:
                showPublicationError(error: .noUsername)
            case .serverError(error: let error):
                showPublicationError(error: .custom(error ?? "An error occurred…"))
            default:
                showPublicationError(error: .custom(error.localizedDescription))
            }
        } else if let error = error as? BeamNoteSharingUtilsError {
            switch error {
            case .canceled:
                break
            default:
                showPublicationError(error: .custom(error.localizedDescription))
            }
        } else {
            showPublicationError(error: .custom(error.localizedDescription))
        }
    }

    private func showPublicationError(error: NoteHeaderPublishButton.ErrorMessage) {
        publishShowError = error
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .seconds(2))) {
            publishShowError = nil
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: BeamSpacing._40) {
                dateView
                    .opacity(model.note?.type.isJournal == true ? 0 : 1)
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
        @Published var note: BeamNote? {
            didSet {
                guard note != oldValue else { return }
                updateOnNoteChanged()
            }
        }
        weak var state: BeamState?

        // title editing
        @Published fileprivate var titleText: String = ""
        @Published fileprivate var titleSelectedRange: Range<Int>?
        @Published fileprivate var isEditingTitle = false
        @Published fileprivate var isTitleTaken = false
        @Published fileprivate var wiggleValue = CGFloat(0)

        // publishing
        @Published fileprivate var publishState: NoteHeaderPublishButton.PublishButtonState = .isPrivate
        @Published fileprivate var justCopiedLinkFrom: NoteHeaderView.CopyLinkSource?
        private var publishingDispatchItem: DispatchWorkItem?
        private var copyLinkDispatchItem: DispatchWorkItem?
        private var noteObservers = Set<AnyCancellable>()

        fileprivate var canEditTitle: Bool {
            note?.type.isJournal == false
        }

        init(note: BeamNote? = nil, state: BeamState? = nil) {
            self.state = state
            self.note = note
        }

        private func updateOnNoteChanged() {
            self.noteObservers.removeAll()
            if let note = note {
                note.$publicationStatus.dropFirst().removeDuplicates().sink { [weak self] newValue in
                    guard self?.publishState == .isPublic || self?.publishState == .isPrivate else { return }
                    self?.publishState = newValue.isPublic ? .isPublic : .isPrivate
                }.store(in: &noteObservers)
                note.$title.dropFirst().sink { [weak self] newTitle in
                    guard self?.isEditingTitle != true && self?.titleText != newTitle else { return }
                    self?.titleText = newTitle
                }.store(in: &noteObservers)
            }
            self.titleText = note?.title ?? ""
            self.publishState = note?.publicationStatus.isPublic == true ? .isPublic : .isPrivate
        }

        func textFieldDidChange(_ text: String) {
            titleSelectedRange = nil
            let newTitle = formatToValidTitle(titleText)
            let existingNote = DocumentManager().loadDocumentByTitle(title: newTitle)
            self.isTitleTaken = existingNote != nil && existingNote?.id != note?.id
        }

        func resetEditingState() {
            titleText = note?.title ?? ""
            isEditingTitle = false
            isTitleTaken = false
            wiggleValue = 0
        }

        func formatToValidTitle(_ title: String) -> String {
            return BeamNote.validTitle(fromTitle: title)
        }

        func commitRenameCard(fromTextField: Bool) {
            let documentManager = DocumentManager()
            let newTitle = formatToValidTitle(titleText)
            guard !newTitle.isEmpty, newTitle != note?.title, !isTitleTaken, canEditTitle else {
                if fromTextField && isTitleTaken {
                    wiggleValue += 1
                } else {
                    resetEditingState()
                }
                return
            }
            note?.updateTitle(newTitle)
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
            guard let note = note else { return }
            BeamNoteSharingUtils.copyLinkToClipboard(for: note) { [weak self] _ in
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
        func togglePublish(completion: @escaping ((Result<Bool, Error>) -> Void)) -> Bool {
            let missingRequirement: Result<Bool, Error> = Result.failure(BeamNoteSharingUtilsError.missingRequirement)

            guard let note = note else {
                completion(missingRequirement)
                return false
            }

            guard ![.publishing, .unpublishing].contains(publishState) else {
                completion(missingRequirement)
                return true
            }
            let isPublic = note.publicationStatus.isPublic

            guard isPublic || BeamNoteSharingUtils.canMakePublic else {
                completion(missingRequirement)
                return false
            }
            if !isPublic {
                publishState = .publishing
                BeamNoteSharingUtils.makeNotePublic(note, becomePublic: true) { [weak self] result in
                    DispatchQueue.main.async {
                        guard case .success(let published) = result, published == true else {
                            self?.noteBecamePublic(false)
                            completion(result)
                            return
                        }
                        self?.noteBecamePublic(true)
                        self?.copyLink(source: .fromPublishButton)
                        completion(result)
                    }
                }
            } else {
                promptConfirmUnpublish(completion: completion)
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

        private func promptConfirmUnpublish(completion: @escaping ((Result<Bool, Error>) -> Void)) {
            let missingRequirement: Result<Bool, Error> = Result.failure(BeamNoteSharingUtilsError.missingRequirement)

            guard let note = note else {
                completion(missingRequirement)
                return
            }
            let alert = NSAlert()
            alert.messageText = "Are you sure you want to unpublish the card \"\(note.title)\"?"
            alert.informativeText = "Others will no longer have access to this card."
            alert.addButton(withTitle: "Unpublish")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .warning
            guard let window = AppDelegate.main.window else { return }
            alert.beginSheetModal(for: window) { [weak self] response in
                guard let self = self, let note = self.note else {
                    completion(missingRequirement)
                    return
                }
                guard response == .alertFirstButtonReturn else {
                    self.publishState = note.publicationStatus.isPublic == true ? .isPublic : .isPrivate
                    completion(Result.failure(BeamNoteSharingUtilsError.canceled))
                    return
                }
                self.publishState = .unpublishing
                BeamNoteSharingUtils.makeNotePublic(note, becomePublic: false) { [weak self] result in
                    defer {
                        completion(result)
                    }
                    guard case .success(let published) = result, published == false else {
                        self?.noteBecamePublic(true)
                        return
                    }
                    DispatchQueue.main.async {
                        self?.noteBecamePublic(false)
                    }
                }
            }
        }

        // MARK: Delete
        private func confirmedDelete() {
            guard let note = note else { return }
            let cmdManager = CommandManagerAsync<DocumentManager>()
            cmdManager.deleteDocuments(ids: [note.id], in: DocumentManager())
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
            guard let note = note else { return }
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
    static var classicModel: NoteHeaderView.ViewModel {
        NoteHeaderView.ViewModel(note: BeamNote(title: "My note title"))
    }
    static var titleTakenModel: NoteHeaderView.ViewModel {
        let model = NoteHeaderView.ViewModel(note: BeamNote(title: "Taken Title"))
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
