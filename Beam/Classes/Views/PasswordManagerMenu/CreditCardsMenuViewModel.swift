//
//  CreditCardsMenuViewModel.swift
//  Beam
//
//  Created by Frank Lefebvre on 27/04/2022.
//

import Foundation
import Combine
import BeamCore

protocol CreditCardsMenuDelegate: WebAutofillMenuDelegate {
    func fillCreditCard(_ entry: CreditCardEntry)
    func deleteCreditCards(_ entries: [CreditCardEntry])
}

final class CreditCardsMenuViewModel: ObservableObject {
    weak var delegate: CreditCardsMenuDelegate?

    @Published var entryDisplayLimit: Int

    private(set) var entries: [CreditCardEntry]
    private(set) var otherCreditCardsViewModel: CreditCardListViewModel

    private var revealMoreItemsInList = false
    private var otherCreditCardsDialog: PopoverWindow?
    private var waitingForAuthentication = false
    private var subscribers = Set<AnyCancellable>()

    init(entries: [CreditCardEntry]) {
        self.entries = entries
        self.entryDisplayLimit = 1
        self.otherCreditCardsViewModel = CreditCardListViewModel()
    }

    func resetItems() {
        revertToFirstItem()
    }

    func revertToFirstItem() {
        entryDisplayLimit = 1
    }

    func revealMoreItemsForCurrentHost() {
        entryDisplayLimit = 3
    }

    func showOtherCreditCards() {
        delegate?.dismissMenu()
        guard let mainWindow = AppDelegate.main.window else { return }
        guard let childWindow = CustomPopoverPresenter.shared.presentPopoverChildWindow(canBecomeKey: true, canBecomeMain: false, withShadow: true, useBeamShadow: false, movable: true, autocloseIfNotMoved: false) else { return }
        otherCreditCardsDialog = childWindow
        let otherCreditCards = OtherCreditCardsSheet(viewModel: otherCreditCardsViewModel) { [weak self] entry in
            self?.closeOtherCreditCardsDialog()
            self?.delegate?.fillCreditCard(entry)
        } onRemove: { [weak self] entries in
            self?.delegate?.deleteCreditCards(entries)
        } onDismiss: { [weak self] in
            self?.closeOtherCreditCardsDialog()
            self?.resetItems()
        }
        let position = CGPoint(x: (mainWindow.frame.size.width - otherCreditCards.width) / 2, y: (mainWindow.frame.size.height + otherCreditCards.height) / 2)
        childWindow.setView(with: otherCreditCards, at: position, fromTopLeft: true)
        childWindow.makeKeyAndOrderFront(nil)
    }

    func fillCreditCard(_ entry: CreditCardEntry) {
        delegate?.dismissMenu()
        Task { @MainActor in
            waitingForAuthentication = true
            if await DeviceAuthenticationManager.shared.checkDeviceAuthentication() {
                delegate?.fillCreditCard(entry)
            }
            waitingForAuthentication = false
        }
    }

    func close() {
        closeOtherCreditCardsDialog()
    }

    var isPresentingModalDialog: Bool {
        otherCreditCardsDialog != nil || waitingForAuthentication
    }

    private func closeOtherCreditCardsDialog() {
        otherCreditCardsDialog?.close()
        otherCreditCardsDialog = nil
    }
}
