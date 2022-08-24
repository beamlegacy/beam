//
//  CreditCardsMenu.swift
//  Beam
//
//  Created by Beam on 27/04/2022.
//

import SwiftUI

struct CreditCardsMenu: View {
    @ObservedObject var viewModel: CreditCardsMenuViewModel

    @State private var height: CGFloat?

    var body: some View {
        FormatterViewBackground(boxCornerRadius: 10) {
            VStack(alignment: .leading, spacing: 0) {
                if !viewModel.autofillMenuItems.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(viewModel.autofillMenuItems) { item in
                            menuItemView(item: item) { newState in
                                viewModel.handleStateChange(itemId: item.id, newState: newState)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                ForEach(viewModel.otherMenuItems) { item in
                    menuItemView(item: item) { newState in
                        viewModel.handleStateChange(itemId: item.id, newState: newState)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .background(GeometryReader { proxy in
                BeamColor.WebFieldAutofill.popupBackground.swiftUI
                    .preference(key: HeightKey.self, value: proxy.size.height)
            })
            .onPreferenceChange(HeightKey.self) {
                self.height = $0
            }
            .animation(nil)
        }
        .frame(width: 305, height: height, alignment: .top)
        .animation(nil)
    }

    @ViewBuilder
    func menuItemView(item: CreditCardsMenuViewModel.MenuItem, onStateChange: @escaping (WebFieldAutofillMenuCellState) -> Void) -> some View {
        let highlightState = viewModel.highlightState(of: item.id)
        switch item {
        case .autofillEntry(let entry):
            StoredCreditCardCell(cardDescription: entry.cardDescription, obfuscatedNumber: entry.obfuscatedNumber, cardImageName: entry.typeImageName, isHighlighted: highlightState) { newState in
                onStateChange(newState)
                if newState == .clicked {
                    viewModel.fillCreditCard(entry)
                }
            }
        case .showMore:
            OtherCreditCardsCell(isHighlighted: highlightState) { newState in
                onStateChange(newState)
                if newState == .clicked {
                    viewModel.revealMoreItemsForCurrentHost()
                }
            }
        case .showAll:
            OtherCreditCardsCell(isHighlighted: highlightState) { newState in
                onStateChange(newState)
                if newState == .clicked {
                    viewModel.showOtherCreditCards()
                }
            }
        case .separator:
            Separator(horizontal: true)
        }
    }

    private struct HeightKey: FloatPreferenceKey {}
}

struct CreditCardsMenu_Previews: PreviewProvider {
    static var viewModel: CreditCardsMenuViewModel {
        let entries = [CreditCardEntry(cardDescription: "Personal card", cardNumber: "4970321045671234", cardHolder: "John Appleseed", expirationMonth: 4, expirationYear: 2023)]
        return CreditCardsMenuViewModel(entries: entries)
    }

    static var previews: some View {
        CreditCardsMenu(viewModel: viewModel)
    }
}
