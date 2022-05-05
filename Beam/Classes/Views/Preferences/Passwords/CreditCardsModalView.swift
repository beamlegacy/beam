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
    var allCreditCards: [CreditCardTableViewItem]
    var onSelectionChanged: (IndexSet) -> Void

    var creditCardsColumns = [
        TableViewColumn(key: "cardDescription", title: "Card Description", type: TableViewColumn.ColumnType.IconAndText, editable: true, sortable: false, resizable: false, width: 200, fontSize: 11),
        TableViewColumn(key: "cardInformations", title: "Card Informations", type: TableViewColumn.ColumnType.TwoTextField, editable: true, sortable: false, resizable: false, width: 200, fontSize: 11),
        TableViewColumn(key: "cardDate", title: "Card Date", type: TableViewColumn.ColumnType.Text, editable: true, sortable: false, resizable: false, width: 70, fontSize: 11)
    ]

    var body: some View {
        TableView(customRowHeight: 48, hasSeparator: true, hasHeader: false, allowsMultipleSelection: false,
                  items: allCreditCards, columns: creditCardsColumns, creationRowTitle: nil) { (_, _) in

        } onSelectionChanged: { idx in
            onSelectionChanged(idx)
        }.frame(width: 526)
    }
}

struct CreditCardsTableView_Previews: PreviewProvider {
    static var previews: some View {
        CreditCardsTableView(allCreditCards: [CreditCardEntry(cardDescription: "Black Card", cardNumber: "0000000000000000", cardHolder: "Jean-Louis Darmon", expirationMonth: 3, expirationYear: 2025)].map(CreditCardTableViewItem.init), onSelectionChanged: {_ in})
    }
}

struct CreditCardInformations {
    var cardNumber: String
    var cardHolder: String
}

@objcMembers
class CreditCardTableViewItem: TwoTextFieldViewItem {
    var cardDate: String

    init(creditCard: CreditCardEntry) {
        let mm = String(format: "%02d", creditCard.expirationMonth)
        let yy = String(format: "%02d", creditCard.expirationYear % 100)
        self.cardDate = "\(mm)/\(yy)"
        super.init()
        self.favIcon = NSImage(named: "preferences-credit_card")
        self.text = creditCard.cardDescription
        self.topTextFieldValue = creditCard.cardNumber
        self.botTextFieldValue = creditCard.cardHolder
        self.topTextFieldPlaceholder = "Card Number"
        self.botTextFieldPlaceholder = "Cardholder"
    }

    override func loadRemoteFavIcon(completion: @escaping (NSImage) -> Void) {
        completion(NSImage(named: "preferences-credit_card")!)
    }
}
