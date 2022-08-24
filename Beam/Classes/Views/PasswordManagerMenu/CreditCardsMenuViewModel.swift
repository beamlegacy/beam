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
    enum MenuItem: Equatable, Identifiable {
        case autofillEntry(CreditCardEntry)
        case showMore
        case showAll
        case separator(Int)

        var id: String {
            switch self {
            case .autofillEntry(let entry):
                return "autofill \(entry.cardNumber) \(entry.expirationMonth) \(entry.expirationYear)"
            case .showMore:
                return "showmore"
            case .showAll:
                return "showall"
            case .separator(let identifier):
                return "separator \(identifier)"
            }
        }

        var isSelectable: Bool {
            switch self {
            case .separator:
                return false
            default:
                return true
            }
        }

        func performAction(with viewModel: CreditCardsMenuViewModel) {
            switch self {
            case .autofillEntry(let entry):
                viewModel.fillCreditCard(entry)
            case .showMore:
                viewModel.revealMoreItemsForCurrentHost()
            case .showAll:
                viewModel.showOtherCreditCards()
            default:
                break
            }
        }
    }

    weak var delegate: CreditCardsMenuDelegate?

    @Published var autofillMenuItems: [MenuItem]
    @Published var otherMenuItems: [MenuItem]

    private(set) var entries: [CreditCardEntry]
    private(set) var otherCreditCardsViewModel: CreditCardListViewModel

    private let selectionHandler = WebAutofillMenuSelectionHandler()
    private var entryDisplayLimit: Int
    private var otherCreditCardsDialog: PopoverWindow?
    private var waitingForAuthentication = false
    private var subscribers = Set<AnyCancellable>()

    init(entries: [CreditCardEntry]) {
        self.entries = entries
        self.entryDisplayLimit = 1
        self.autofillMenuItems = []
        self.otherMenuItems = []
        self.otherCreditCardsViewModel = CreditCardListViewModel()
        self.updateDisplay()
    }

    func handleStateChange(itemId: String, newState: WebFieldAutofillMenuCellState) {
        if selectionHandler.handleStateChange(itemId: itemId, newState: newState) {
            objectWillChange.send()
        }
    }

    func highlightState(of itemId: String) -> Bool {
        selectionHandler.highlightState(of: itemId)
    }

    func resetItems() {
        revertToFirstItem()
    }

    func revertToFirstItem() {
        entryDisplayLimit = 1
        updateDisplay()
    }

    func revealMoreItemsForCurrentHost() {
        entryDisplayLimit = 3
        updateDisplay()
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

    private func updateDisplay() {
        autofillMenuItems = entries.prefix(entryDisplayLimit).map { MenuItem.autofillEntry($0) }
        if entries.count > entryDisplayLimit {
            otherMenuItems = [.separator(1),
                              entryDisplayLimit == 1 ? .showMore : .showAll
            ]
        } else {
            otherMenuItems = []
        }
        selectionHandler.update(selectableIds: (autofillMenuItems + otherMenuItems).filter(\.isSelectable).map(\.id))
    }
}

extension CreditCardsMenuViewModel: KeyEventHijacking {
    func onKeyDown(with event: NSEvent) -> Bool {
        switch selectionHandler.onKeyDown(with: event) {
        case .none:
            break
        case .refresh:
            objectWillChange.send()
        case .select(let itemId):
            if let menuItem = (autofillMenuItems + otherMenuItems).first(where: { $0.id == itemId }) {
                menuItem.performAction(with: self)
            }
        }
        return true
    }
}
