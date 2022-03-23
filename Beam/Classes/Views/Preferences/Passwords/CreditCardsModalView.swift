//
//  CreditCardsModalView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 09/07/2021.
//

import Foundation
import SwiftUI
import BeamCore

struct CreditCardsModalView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var creditCardIsSelected = false
    @State private var selectedEntries = IndexSet()

    var body: some View {
        VStack {
            HStack {
                Text("Credit Cards")
                    .font(BeamFont.semibold(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                Spacer()
            }.padding(20)

            CreditCardsTableView(allCreditCards: [], onSelectionChanged: { idx in
                DispatchQueue.main.async {
                    self.creditCardIsSelected = idx.count > 0
                    self.selectedEntries = idx
                }
            }).frame(width: 526, height: 242, alignment: .center)
            .border(BeamColor.Mercury.swiftUI, width: 1)
            .background(BeamColor.Generic.background.swiftUI)

            HStack {
                Button {
                } label: {
                    Image("basicAdd")
                        .renderingMode(.template)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                }.buttonStyle(BorderedButtonStyle())

                Button {
                } label: {
                    Image("basicRemove")
                        .renderingMode(.template)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                }.buttonStyle(BorderedButtonStyle())
                .disabled(!self.creditCardIsSelected)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                }.buttonStyle(BorderedButtonStyle())
            }.padding(.vertical, 20)
            .frame(width: 526, alignment: .center)
        }.frame(width: 568, height: 361, alignment: .center)
    }

    private func dismiss() {
        presentationMode.wrappedValue.dismiss()
    }
}

struct CreditCardsModalView_Previews: PreviewProvider {
    static var previews: some View {
        CreditCardsModalView()
    }
}

struct CreditCardsTableView: View {
    var allCreditCards: [CreditCard]
    var onSelectionChanged: (IndexSet) -> Void

    @State var allCreditCardsItem = [CreditCardTableViewItem]()
    var creditCardsColumns = [
        TableViewColumn(key: "cardDescription", title: "Card Description", type: TableViewColumn.ColumnType.IconAndText, editable: true, sortable: false, resizable: false, width: 200, fontSize: 11),
        TableViewColumn(key: "cardInformations", title: "Card Informations", type: TableViewColumn.ColumnType.TwoTextField, editable: true, sortable: false, resizable: false, width: 200, fontSize: 11),
        TableViewColumn(key: "cardDate", title: "Card Date", type: TableViewColumn.ColumnType.Text, editable: true, sortable: false, resizable: false, width: 70, fontSize: 11)
    ]

    var body: some View {
        TableView(customRowHeight: 48, hasSeparator: true, hasHeader: false, allowsMultipleSelection: false,
                  items: allCreditCardsItem, columns: creditCardsColumns, creationRowTitle: nil) { (_, _) in

        } onSelectionChanged: { idx in
            onSelectionChanged(idx)
        }.onAppear {
            refreshAllCreditCards()
        }.frame(width: 526)
    }

    private func refreshAllCreditCards() {
        for creditCard in allCreditCards {
            allCreditCardsItem.append(CreditCardTableViewItem(creditCard: creditCard))
        }
    }
}

struct CreditCardsTableView_Previews: PreviewProvider {
    static var previews: some View {
        CreditCardsTableView(allCreditCards: [CreditCard(cardDescription: "Black Card", cardNumber: 0000000000000000, cardHolder: "Jean-Louis Darmon", cardDate: BeamDate.now)], onSelectionChanged: {_ in})
    }
}

struct CreditCardInformations {
    var cardNumber: String
    var cardHolder: String
}

@objcMembers
class CreditCardTableViewItem: TwoTextFieldViewItem {
    var cardDate: String

    init(creditCard: CreditCard) {
//        self.cardInformations = CreditCardInformations(cardNumber: String(creditCard.cardNumber), cardHolder: creditCard.cardHolder)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/YY"
        self.cardDate = dateFormatter.string(from: creditCard.cardDate)
        super.init()
        self.favIcon = NSImage(named: "preferences-credit-card")
        self.text = creditCard.cardDescription
        self.topTextFieldValue = String(creditCard.cardNumber)
        self.botTextFieldValue = creditCard.cardHolder
        self.topTextFieldPlaceholder = "Card Number"
        self.botTextFieldPlaceholder = "Cardholder"
    }
}
