//
//  WebFieldAutofillOverlay.swift
//  Beam
//
//  Created by Frank Lefebvre on 01/04/2022.
//

import Foundation
import BeamCore
import Combine

/// Embeds password manager child windows and frame info for the currently focused input field.
/// Lifecycle: created when field gets focus, destroyed when field loses focus.
final class WebFieldAutofillOverlay {
    private(set) var frameInfo: WKFrameInfo? // used in menu delegate, needs to be kept around
    let elementId: String
    let autocompleteGroup: WebAutocompleteGroup

    private var scope = Set<AnyCancellable>()
    private weak var page: WebPage?
    private var scrollUpdater: PassthroughSubject<WebFrames.FrameInfo, Never>
    private weak var currentFieldLocator: WebFieldLocator?
    private var passwordMenuPopover: WebAutofillPopoverContainer?
    private var menuViewModel: PasswordManagerMenuViewModel?
    private var creditCardViewModel: CreditCardsMenuViewModel?
    private var buttonPopover: WebAutofillPopoverContainer?
    private let elementEdgeInsets: BeamEdgeInsets
    private let iconAction: (WKFrameInfo?) -> Void

    init(page: WebPage?, scrollUpdater: PassthroughSubject<WebFrames.FrameInfo, Never>, frameInfo: WKFrameInfo?, elementId: String, inGroup autocompleteGroup: WebAutocompleteGroup, elementEdgeInsets: BeamEdgeInsets = .zero, iconAction: @escaping (WKFrameInfo?) -> Void) {
        self.page = page
        self.scrollUpdater = scrollUpdater
        self.frameInfo = frameInfo
        self.elementId = elementId
        self.autocompleteGroup = autocompleteGroup
        self.elementEdgeInsets = elementEdgeInsets
        self.iconAction = iconAction
        (page as? BrowserTab)?.state?.$omniboxInfo
            .map(\.isFocused)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] visible in
                self?.updateOmniboxState(visible: visible)
            }.store(in: &scope)
    }

    deinit {
        dismissPasswordManagerMenu()
        menuViewModel?.close()
        menuViewModel = nil
        clearIcon()
    }

    private var fieldLocator: WebFieldLocator {
        if let currentFieldLocator = currentFieldLocator {
            return currentFieldLocator
        }
        let newFieldLocator = WebFieldLocator(page: page, elementId: elementId, frameInfo: frameInfo, scrollUpdater: scrollUpdater)
        currentFieldLocator = newFieldLocator
        return newFieldLocator
    }

    func showIcon(frameInfo: WKFrameInfo?) {
        guard let page = page else { return }
        if let frameInfo = frameInfo {
            self.frameInfo = frameInfo
        }
        guard buttonPopover == nil, let buttonWindow = CustomPopoverPresenter.shared.presentPopoverChildWindow(canBecomeKey: false, canBecomeMain: false, withShadow: false, movable: false, storedInPresenter: true) else { return }
        buttonWindow.isMovableByWindowBackground = false
        let buttonPopover = WebAutofillPopoverContainer(window: buttonWindow, page: page, fieldLocator: fieldLocator) { [elementEdgeInsets] rect in
            let rect = rect.inset(by: elementEdgeInsets)
            return CGPoint(x: rect.maxX - 24 - 16, y: rect.midY + 12)
        }
        let imageName: String
        switch autocompleteGroup.action {
        case .login, .createAccount:
            imageName = "autofill-password"
        case .personalInfo:
            imageName = "autofill-form"
        case .payment:
            imageName = "preferences-credit_card" // FIXME: add asset
        }
        let buttonView = WebFieldAutofillButton(imageName: imageName) { [weak self] in
            if let self = self, self.passwordMenuPopover == nil {
                self.iconAction(self.frameInfo)
            }
        }
        buttonWindow.setView(with: buttonView, at: buttonPopover.currentOrigin, fromTopLeft: true)
        self.buttonPopover = buttonPopover
    }

    func clearIcon() {
        if let buttonPopoverWindow = buttonPopover?.window {
            CustomPopoverPresenter.shared.dismissPopoverWindow(buttonPopoverWindow)
        }
        buttonPopover = nil
    }

    func showPasswordManagerMenu(frameInfo: WKFrameInfo?, viewModel: PasswordManagerMenuViewModel) {
        guard let page = self.page else { return }
        guard passwordMenuPopover == nil else { return }
        showIcon(frameInfo: frameInfo) // make sure icon is always created before menu
        let passwordManagerMenu = PasswordManagerMenu(viewModel: viewModel)
        guard let passwordWindow = CustomPopoverPresenter.shared.presentPopoverChildWindow(canBecomeKey: false, canBecomeMain: false, withShadow: false, useBeamShadow: true, lightBeamShadow: true, storedInPresenter: true) else { return }
        let passwordMenuPopover = WebAutofillPopoverContainer(window: passwordWindow, page: page, topEdgeHeight: 24, fieldLocator: fieldLocator) { rect in
            CGPoint(x: rect.minX, y: rect.minY)
        }
        passwordWindow.setView(with: passwordManagerMenu, at: passwordMenuPopover.currentOrigin, fromTopLeft: true)
        passwordWindow.delegate = viewModel.passwordGeneratorViewModel
        self.passwordMenuPopover = passwordMenuPopover
        self.menuViewModel = viewModel
    }

    func showCreditCardsMenu(frameInfo: WKFrameInfo?, viewModel: CreditCardsMenuViewModel) {
        guard let page = self.page else { return }
        guard passwordMenuPopover == nil else { return }
        showIcon(frameInfo: frameInfo) // make sure icon is always created before menu
        let passwordManagerMenu = CreditCardsMenu(viewModel: viewModel)
        guard let passwordWindow = CustomPopoverPresenter.shared.presentPopoverChildWindow(canBecomeKey: false, canBecomeMain: false, withShadow: false, useBeamShadow: true, lightBeamShadow: true, storedInPresenter: true) else { return }
        let passwordMenuPopover = WebAutofillPopoverContainer(window: passwordWindow, page: page, topEdgeHeight: 24, fieldLocator: fieldLocator) { rect in
            CGPoint(x: rect.minX, y: rect.minY)
        }
        passwordWindow.setView(with: passwordManagerMenu, at: passwordMenuPopover.currentOrigin, fromTopLeft: true)
//        passwordWindow.delegate = viewModel.passwordGeneratorViewModel
        self.passwordMenuPopover = passwordMenuPopover
        self.creditCardViewModel = viewModel
    }

    func revertMenuToDefault() {
        menuViewModel?.revertToFirstItem()
    }

    func dismissPasswordManagerMenu() {
        if let popoverWindow = passwordMenuPopover?.window {
            CustomPopoverPresenter.shared.dismissPopoverWindow(popoverWindow)
        }
        passwordMenuPopover = nil
    }

    private func updateOmniboxState(visible: Bool) {
        if visible {
            // omnibox is visible: remove child windows
            dismissPasswordManagerMenu()
            clearIcon()
        } else if page?.isActiveTab() ?? false {
            // omnibox is hidden, and the field still has focus: show icon and menu if exists
            showIcon(frameInfo: nil)
            if let menuViewModel = menuViewModel {
                showPasswordManagerMenu(frameInfo: nil, viewModel: menuViewModel)
            }
        }
    }
}
