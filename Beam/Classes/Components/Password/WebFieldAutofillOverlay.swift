//
//  WebFieldAutofillOverlay.swift
//  Beam
//
//  Created by Frank Lefebvre on 01/04/2022.
//

import Foundation
import BeamCore
import Combine
import SwiftUI

/// Embeds password manager child windows and frame info for the currently focused input field.
/// Lifecycle: created when field gets focus, destroyed when field loses focus.
final class WebFieldAutofillOverlay {
    private enum MenuViewModel {
        case none
        case password(PasswordManagerMenuViewModel)
        case creditCard(CreditCardsMenuViewModel)

        func revert() {
            switch self {
            case .none:
                break
            case .password(let viewModel):
                viewModel.revertToFirstItem()
            case .creditCard(let viewModel):
                viewModel.revertToFirstItem()
            }
        }

        func close() {
            switch self {
            case .none:
                break
            case .password(let viewModel):
                viewModel.close()
            case .creditCard(let viewModel):
                viewModel.close()
            }
        }

        var isPresentingModalDialog: Bool {
            switch self {
            case .none:
                return false
            case .password(let viewModel):
                return viewModel.isPresentingModalDialog
            case .creditCard(let viewModel):
                return viewModel.isPresentingModalDialog
            }
        }

        var keyEventHijacking: KeyEventHijacking? {
            switch self {
            case .none:
                return nil
            case .password(let viewModel):
                return viewModel
            case .creditCard(let viewModel):
                return viewModel
            }
        }
    }

    private(set) var frameInfo: WKFrameInfo? // used in menu delegate, needs to be kept around
    let elementId: String
    let autofillGroup: WebAutofillGroup

    private var scope = Set<AnyCancellable>()
    private weak var page: WebPage?
    private var scrollUpdater: PassthroughSubject<WebFrames.FrameInfo, Never>
    private weak var currentFieldLocator: WebFieldLocator?
    private var menuPopover: WebAutofillPopoverContainer?
    private var menuViewModel: MenuViewModel = .none
    private var buttonPopover: WebAutofillPopoverContainer?
    private let elementEdgeInsets: BeamEdgeInsets
    private let iconAction: (WKFrameInfo?) -> Void

    init(page: WebPage?, scrollUpdater: PassthroughSubject<WebFrames.FrameInfo, Never>, frameInfo: WKFrameInfo?, elementId: String, inGroup autofillGroup: WebAutofillGroup, elementEdgeInsets: BeamEdgeInsets = .zero, iconAction: @escaping (WKFrameInfo?) -> Void) {
        self.page = page
        self.scrollUpdater = scrollUpdater
        self.frameInfo = frameInfo
        self.elementId = elementId
        self.autofillGroup = autofillGroup
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

    private var fieldLocator: WebFieldLocator {
        if let currentFieldLocator = currentFieldLocator {
            return currentFieldLocator
        }
        let newFieldLocator = WebFieldLocator(page: page, elementId: elementId, frameInfo: frameInfo, scrollUpdater: scrollUpdater)
        currentFieldLocator = newFieldLocator
        return newFieldLocator
    }

    var hasVisibleInterface: Bool {
        buttonPopover?.window != nil && menuPopover?.window != nil
    }

    var isPresentingModalDialog: Bool {
        menuViewModel.isPresentingModalDialog
    }

    func dismiss() {
        menuViewModel.close()
        menuViewModel = .none
        dismissMenu()
        clearIcon()
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
        let renderingMode: Image.TemplateRenderingMode
        switch autofillGroup.action {
        case .login, .createAccount:
            imageName = "autofill-password"
            renderingMode = .template
        case .personalInfo:
            imageName = "autofill-form"
            renderingMode = .template
        case .payment:
            imageName = "autofill-card_generic"
            renderingMode = .original
        }
        let buttonView = WebFieldAutofillButton(imageName: imageName, renderingMode: renderingMode) { [weak self] in
            if let self = self, self.menuPopover == nil {
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

    private func showMenu(frameInfo: WKFrameInfo?, viewModel: MenuViewModel) {
        guard let page = self.page else { return }
        guard menuPopover == nil else { return }
        showIcon(frameInfo: frameInfo) // make sure icon is always created before menu
        guard let popoverWindow = CustomPopoverPresenter.shared.presentPopoverChildWindow(canBecomeKey: false, canBecomeMain: false, withShadow: false, useBeamShadow: true, lightBeamShadow: true, movable: false, storedInPresenter: true) else { return }
        let menuPopover = WebAutofillPopoverContainer(window: popoverWindow, page: page, topEdgeHeight: 24, fieldLocator: fieldLocator) { rect in
            CGPoint(x: rect.minX, y: rect.minY)
        }
        switch viewModel {
        case .none:
            break
        case .password(let viewModel):
            let menuView = PasswordManagerMenu(viewModel: viewModel)
            popoverWindow.setView(with: menuView, at: menuPopover.currentOrigin, fromTopLeft: true)
            popoverWindow.delegate = viewModel.passwordGeneratorViewModel
            KeyEventHijacker.shared.register(handler: viewModel, forKeyCodes: [.up, .down, .enter, .return])
        case .creditCard(let viewModel):
            let menuView = CreditCardsMenu(viewModel: viewModel)
            popoverWindow.setView(with: menuView, at: menuPopover.currentOrigin, fromTopLeft: true)
            KeyEventHijacker.shared.register(handler: viewModel, forKeyCodes: [.up, .down, .enter, .return])
        }
        self.menuPopover = menuPopover
        self.menuViewModel = viewModel
    }

    func showPasswordManagerMenu(frameInfo: WKFrameInfo?, viewModel: PasswordManagerMenuViewModel) {
        showMenu(frameInfo: frameInfo, viewModel: .password(viewModel))
    }

    func showCreditCardsMenu(frameInfo: WKFrameInfo?, viewModel: CreditCardsMenuViewModel) {
        showMenu(frameInfo: frameInfo, viewModel: .creditCard(viewModel))
    }

    func revertMenuToDefault() {
        menuViewModel.revert()
    }

    func dismissMenu() {
        if let popoverWindow = menuPopover?.window {
            CustomPopoverPresenter.shared.dismissPopoverWindow(popoverWindow)
        }
        if let handler = menuViewModel.keyEventHijacking {
            KeyEventHijacker.shared.unregister(handler: handler)
        }
        menuPopover = nil
    }

    private func updateOmniboxState(visible: Bool) {
        if visible {
            // omnibox is visible: remove child windows
            dismissMenu()
            clearIcon()
        } else if page?.isActiveTab() ?? false {
            // omnibox is hidden, and the field still has focus: show icon and menu if exists
            showIcon(frameInfo: nil)
            switch menuViewModel {
            case .none:
                break
            case .password(let viewModel):
                showPasswordManagerMenu(frameInfo: nil, viewModel: viewModel)
            case .creditCard(let viewModel):
                showCreditCardsMenu(frameInfo: nil, viewModel: viewModel)
            }
        }
    }
}
