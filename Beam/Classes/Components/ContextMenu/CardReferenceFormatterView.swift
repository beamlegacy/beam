//
//  CardReferenceFormatterView.swift
//  Beam
//
//  Created by Remi Santos on 19/08/2021.
//

import Foundation
import SwiftUI
import BeamCore

private struct CardReferenceFormatterContainerView: View {

    class ViewModel: BaseFormatterViewViewModel, ObservableObject { }

    static func idealSize(searchCardContent: Bool) -> CGSize {
        CGSize(width: searchCardContent ? 380 : 280, height: 240)
    }

    @ObservedObject var viewModel: ViewModel = ViewModel()
    @ObservedObject var listModel: DestinationNoteAutocompleteList.Model
    var onSelectResult: (() -> Void)?
    private var size: CGSize {
        Self.idealSize(searchCardContent: listModel.searchCardContent)
    }
    var body: some View {
        let computedSize = size
        return FormatterViewBackground {
            ScrollView {
                DestinationNoteAutocompleteList(model: listModel, onSelectAutocompleteResult: onSelectResult)
            }.frame(maxHeight: computedSize.height)
        }
        .frame(width: computedSize.width)
        .fixedSize(horizontal: false, vertical: true)
        .frame(height: computedSize.height, alignment: .topLeading)
        .formatterViewBackgroundAnimation(with: viewModel)
    }
}

class CardReferenceFormatterView: FormatterView {

    private var hostView: NSHostingView<CardReferenceFormatterContainerView>?
    private var subviewModel = CardReferenceFormatterContainerView.ViewModel()
    private var listModel = DestinationNoteAutocompleteList.Model()
    private var initialText: String?
    private var searchCardContent: Bool = false
    private var onSelectNote: ((_ noteId: UUID, _ elementId: UUID?) -> Void)?
    private var onSelectCreate: ((_ title: String) -> Void)?

    override var idealSize: NSSize {
        CardReferenceFormatterContainerView.idealSize(searchCardContent: searchCardContent)
    }

    override var handlesTyping: Bool { true }
    override var typingAttributes: [BeamText.Attribute]? {
        searchCardContent ? nil : [BeamTextEdit.formatterPlaceholderAttribute]
    }

    var typingPrefix = 0
    var typingSuffix = 0

    convenience init(initialText: String?, searchCardContent: Bool = false,
                     onSelectNoteHandler: ((_ noteId: UUID, _ elementId: UUID?) -> Void)? = nil,
                     onCreateNoteHandler: ((_ title: String) -> Void)? = nil) {
        self.init(frame: CGRect.zero)
        self.searchCardContent = searchCardContent
        self.onSelectNote = onSelectNoteHandler
        self.onSelectCreate = onCreateNoteHandler
        self.initialText = initialText
        setupUI()
    }

    override func animateOnAppear(completionHandler: (() -> Void)? = nil) {
        super.animateOnAppear()
        subviewModel.visible = true
        DispatchQueue.main.asyncAfter(deadline: .now() + FormatterView.appearAnimationDuration) {
            completionHandler?()
        }
    }

    override func animateOnDisappear(completionHandler: (() -> Void)? = nil) {
        super.animateOnDisappear()
        subviewModel.visible = false
        DispatchQueue.main.asyncAfter(deadline: .now() + FormatterView.disappearAnimationDuration) {
            completionHandler?()
        }
    }

    override func setupUI() {
        super.setupUI()
        listModel.data = AppDelegate.main.data
        listModel.searchCardContent = searchCardContent
        listModel.allowCmdEnter = false

        let rootView = CardReferenceFormatterContainerView(viewModel: subviewModel, listModel: listModel) { [weak self] in
            self?.validateSelectedResult()
        }
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = self.bounds
        self.addSubview(hostingView)
        hostView = hostingView
        self.layer?.masksToBounds = false
        updateItemsForSearchText(initialText ?? "")
    }

    private func updateItemsForSearchText(_ text: String) {
        listModel.searchText = text
    }

    private func selectNextItem() {
        _ = listModel.handleCursorMovement(.down)
    }

    private func selectPreviousItem() {
        _ = listModel.handleCursorMovement(.up)
    }

    @discardableResult
    private func validateSelectedResult() -> Bool {
        guard let selectedResult = listModel.selectedResult else { return false }
        if case let .note(noteId, elementId) = selectedResult.source, let noteIdUnwrapped = noteId {
            onSelectNote?(noteIdUnwrapped, elementId)
        } else if selectedResult.source == .createCard {
            onSelectCreate?(selectedResult.text)
        }
        return true
    }

    // MARK: - keyboard actions
    override func formatterHandlesCursorMovement(direction: CursorMovement,
                                                 modifierFlags: NSEvent.ModifierFlags? = nil) -> Bool {
        return listModel.handleCursorMovement(direction)
    }

    override func formatterHandlesEnter() -> Bool {
        return validateSelectedResult()
    }

    override func formatterHandlesInputText(_ text: String) -> Bool {
        guard handlesTyping, !text.hasPrefix(" ")
        else { return false }
        updateItemsForSearchText(String(text))
        return true
    }
}
