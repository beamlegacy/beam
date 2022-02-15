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
    var leadingPadding: CGFloat
    var onSelectResult: (() -> Void)?
    private var size: CGSize {
        Self.idealSize(searchCardContent: listModel.searchCardContent)
    }
    var body: some View {
        let computedSize = size
        return FormatterViewBackground {
            DestinationNoteAutocompleteList(model: listModel, variation: .TextEditor(leadingPadding: leadingPadding),
                                            allowScroll: true, onSelectAutocompleteResult: onSelectResult)
                .frame(maxHeight: computedSize.height)
        }
        .frame(width: computedSize.width)
        .fixedSize(horizontal: false, vertical: true)
        .frame(height: computedSize.height, alignment: .topLeading)
        .animation(BeamAnimation.easeInOut(duration: 0.15))
        .formatterViewBackgroundAnimation(with: viewModel)
    }
}

class CardReferenceFormatterView: FormatterView {

    private var hostView: NSHostingView<CardReferenceFormatterContainerView>?
    private var subviewModel = CardReferenceFormatterContainerView.ViewModel()
    private var listModel = DestinationNoteAutocompleteList.Model()
    private var initialText: String?
    private var searchCardContent: Bool = false
    private var excludeElements: [UUID] = []
    private var onSelectNote: ((_ noteId: UUID, _ elementId: UUID?) -> Void)?
    private var onSelectCreate: ((_ title: String) -> Void)?

    override var idealSize: CGSize {
        CardReferenceFormatterContainerView.idealSize(searchCardContent: searchCardContent)
    }

    override var handlesTyping: Bool { true }

    private var typingPrefix = 0
    private var typingSuffix = 0

    init(initialText: String?, searchCardContent: Bool = false,
         typingPrefix: Int = 0, typingSuffix: Int = 0,
         excludingElements: [UUID] = [],
         onSelectNoteHandler: ((_ noteId: UUID, _ elementId: UUID?) -> Void)? = nil,
         onCreateNoteHandler: ((_ title: String) -> Void)? = nil) {
        self.typingPrefix = typingPrefix
        self.typingSuffix = typingSuffix
        self.searchCardContent = searchCardContent
        self.onSelectNote = onSelectNoteHandler
        self.onSelectCreate = onCreateNoteHandler
        self.initialText = initialText
        self.excludeElements = excludingElements
        super.init(key: "CardReference", viewType: .inline)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        listModel.excludeElements = excludeElements
        listModel.data = AppDelegate.main.data
        listModel.searchCardContent = searchCardContent
        listModel.allowNewCardShortcut = false

        var leadingPadding: CGFloat = CGFloat(typingPrefix)
        if !searchCardContent && typingPrefix == 1 {
            leadingPadding = 5
        }
        let rootView = CardReferenceFormatterContainerView(viewModel: subviewModel, listModel: listModel, leadingPadding: leadingPadding) { [weak self] in
            self?.validateSelectedResult()
        }
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = self.bounds
        self.addSubview(hostingView)
        hostView = hostingView
        self.layer?.masksToBounds = false
        if searchCardContent || initialText != nil || typingPrefix > 1 {
            enableTypingAttributes()
        }
        updateItemsForSearchText(initialText ?? "")
    }

    private func updateItemsForSearchText(_ text: String) {
        listModel.searchText = text
        if _typedAttributes == nil && !text.isEmpty {
            enableTypingAttributes()
        }
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
        } else if selectedResult.source == .note && listModel.realNameForCardName(selectedResult.text) != selectedResult.text {
            onSelectCreate?(listModel.realNameForCardName(selectedResult.text))
        } else if selectedResult.source == .createCard {
            onSelectCreate?(selectedResult.text)
        }
        return true
    }

    private var _typedAttributes: [BeamText.Attribute]?
    private var _parenthesisAttributes: [BeamText.Attribute]?
    private func enableTypingAttributes() {
        _typedAttributes = [BeamTextEdit.formatterAutocompletingAttribute]
        let parenthesisDecoration = AttributeDecoratedValueAttributedString(attributes: [
            .foregroundColor: BeamColor.LightStoneGray.nsColor
        ], editable: true)
        _parenthesisAttributes = [BeamText.Attribute.decorated(parenthesisDecoration)]
    }
    override func typingAttributes(for range: Range<Int>) -> [(attributes: [BeamText.Attribute], range: Range<Int>)]? {
        guard let _typedAttributes = _typedAttributes else { return nil }
        if searchCardContent, let parenthesisAttributes = _parenthesisAttributes {
                        return [
                (parenthesisAttributes, range.lowerBound - typingPrefix..<range.lowerBound),
                (parenthesisAttributes, range.upperBound..<range.upperBound + typingSuffix)
            ]
        } else {
            return [(_typedAttributes, range.lowerBound - typingPrefix..<range.upperBound + typingSuffix)]
        }
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
