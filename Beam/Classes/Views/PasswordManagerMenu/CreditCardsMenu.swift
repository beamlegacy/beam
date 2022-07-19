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
                VStack(spacing: 0) {
                    ForEach(viewModel.entries.prefix(viewModel.entryDisplayLimit), id: \.self) { entry in
                        StoredCreditCardCell(cardDescription: entry.cardDescription, obfuscatedNumber: entry.obfuscatedNumber, cardImageName: entry.typeImageName) { newState in
                            if newState == .clicked {
                                viewModel.fillCreditCard(entry)
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
                if viewModel.entries.count > viewModel.entryDisplayLimit {
                    Separator(horizontal: true)
                    OtherCreditCardsCell { newState in
                        if newState == .clicked {
                            if viewModel.entryDisplayLimit == 1 {
                                viewModel.revealMoreItemsForCurrentHost()
                            } else {
                                viewModel.showOtherCreditCards()
                            }
                        }
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
