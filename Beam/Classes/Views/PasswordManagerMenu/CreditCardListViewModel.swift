//
//  CreditCardListViewModel.swift
//  Beam
//
//  Created by Frank Lefebvre on 28/04/2022.
//

import Foundation
import Combine
import SwiftUI

final class CreditCardListViewModel: ObservableObject {
    private var creditCardManager: CreditCardAutofillManager
    private var currentSelection = IndexSet() // indices are relative to full list, regardless of filtering options
    private var cancellables = Set<AnyCancellable>()

    private var allCreditCardEntries: [CreditCardEntry] = []

    var allCreditCardTableViewItems: [CreditCardTableViewItem] = []
    var editedCreditCard: CreditCardEntry?
    @Published var disableFillButton = true
    @Published var disableRemoveButton = true
    @Published var isUnlocked = false

    var selectedEntries: [CreditCardEntry] {
        currentSelection.map { allCreditCardEntries[$0] }
    }

    init(creditCardManager: CreditCardAutofillManager = .shared) {
        self.creditCardManager = creditCardManager
        refresh()
        creditCardManager.changePublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in
                self.refresh()
            }
            .store(in: &cancellables)
    }

    func updateSelection(_ idx: IndexSet) {
        guard idx != currentSelection else {
            return
        }
        currentSelection = idx
        disableFillButton = idx.count != 1
        disableRemoveButton = idx.count == 0
    }

    func editCreditCard(row: Int?) {
        if let row = row {
            editedCreditCard = allCreditCardEntries[row]
        } else {
            editedCreditCard = nil
        }
    }

    func saveCreditCard(_ entry: CreditCardEntry) -> Bool {
        var matchingCards = creditCardManager.find(cardNumber: entry.cardNumber)
        if let databaseID = entry.databaseID {
            matchingCards.removeAll { $0.databaseID == databaseID }
        }
        guard !matchingCards.contains(where: { $0.expirationMonth == entry.expirationMonth && $0.expirationYear == entry.expirationYear }) else {
            return false // the card is already in the database
        }
        creditCardManager.save(entry: entry)
        return true
    }

    func deleteSelectedCreditCards() {
        let selectedCreditCards = selectedEntries
        for entry in selectedCreditCards {
            creditCardManager.markDeleted(entry: entry)
        }
    }

    func alertMessageToDeleteSelectedEntries() -> String {
        let entries = selectedEntries
        if entries.count == 1, let entry = entries.first {
            return "Are you sure you want to remove \(entry.cardDescription)?"
        } else {
            return "Are you sure you want to remove \(entries.count) credit cards?"
        }
    }

    func refresh() {
        let savedSelection = Set(selectedEntries)
        let entries = creditCardManager.fetchAll()
        allCreditCardEntries = entries
        allCreditCardTableViewItems = allCreditCardEntries.map(CreditCardTableViewItem.init)
        currentSelection = IndexSet(
            entries.enumerated()
                .filter { (_, entry) in savedSelection.contains(entry) }
                .map { (index, _) in index }
        )
        objectWillChange.send()
    }

    @MainActor
    func checkAuthentication() async {
        isUnlocked = await DeviceAuthenticationManager.shared.checkDeviceAuthentication()
    }
}
