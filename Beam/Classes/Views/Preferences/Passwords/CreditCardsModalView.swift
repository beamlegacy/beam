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
    @ObservedObject var creditCardsViewModel: CreditCardListViewModel

    @State private var showingEditSheet = false
    @State private var showingRemoveAlert = false

    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        VStack {
            HStack {
                Text("Credit Cards")
                    .font(BeamFont.semibold(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                Spacer()
            }.padding(20)

            CreditCardsTableView(allCreditCards: creditCardsViewModel.allCreditCardTableViewItems) { idx in
                creditCardsViewModel.updateSelection(idx)
            } onDoubleTap: { row in
                creditCardsViewModel.editCreditCard(row: row)
                showingEditSheet = true
            }
            .frame(width: 526, height: 242, alignment: .center)
            .border(BeamColor.Mercury.swiftUI, width: 1)
            .background(BeamColor.Generic.background.swiftUI)

            HStack {
                BeamControlGroup {
                    Group {
                        Button {
                            creditCardsViewModel.editCreditCard(row: nil)
                            showingEditSheet = true
                        } label: {
                            Image("basicAdd")
                                .renderingMode(.template)
                                .foregroundColor(BeamColor.Generic.text.swiftUI)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("addCreditCard")
                        Button {
                            self.showingRemoveAlert = true
                        } label: {
                            Image("basicRemove")
                                .renderingMode(.template)
                                .foregroundColor(BeamColor.Generic.text.swiftUI)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("removeCreditCard")
                        .disabled(creditCardsViewModel.disableRemoveButton)
                    }
                }
                .fixedSize()
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                }.buttonStyle(.bordered)
            }
            .padding(.vertical, 20)
            .frame(width: 526, alignment: .center)
        }
        .frame(width: 568, height: 361, alignment: .center)
        .onAppear {
            creditCardsViewModel.refresh()
        }
        .sheet(isPresented: $showingEditSheet) {
            CreditCardEditView(entry: creditCardsViewModel.editedCreditCard) { entry in
                if let entry = entry {
                    creditCardsViewModel.saveCreditCard(entry)
                }
            }
        }
        .alert(isPresented: $showingRemoveAlert) {
            Alert(title: Text(creditCardsViewModel.alertMessageToDeleteSelectedEntries()),
                  primaryButton: .destructive(Text("Remove"), action: {
                creditCardsViewModel.deleteSelectedCreditCards()
            }),
                  secondaryButton: .cancel(Text("Cancel")))
        }
    }

    private func dismiss() {
        presentationMode.wrappedValue.dismiss()
    }
}

struct CreditCardsModalView_Previews: PreviewProvider {
    static var previews: some View {
        CreditCardsModalView(creditCardsViewModel: CreditCardListViewModel())
    }
}

struct CreditCardsTableView: View {
    var allCreditCards: [CreditCardTableViewItem]
    var onSelectionChanged: (IndexSet) -> Void
    var onDoubleTap: ((Int) -> Void)?

    static let creditCardsColumns = [
        TableViewColumn(key: "cardDescription", title: "Card Description", type: TableViewColumn.ColumnType.IconAndText, editable: true, sortable: false, resizable: false, width: 200, fontSize: 11),
        TableViewColumn(key: "cardInformations", title: "Card Details", type: TableViewColumn.ColumnType.TwoTextField, editable: true, sortable: false, resizable: false, width: 200, fontSize: 11),
        TableViewColumn(key: "cardDate", title: "Card Date", type: TableViewColumn.ColumnType.Text, editable: true, sortable: false, resizable: false, width: 70, fontSize: 11)
    ]

    var body: some View {
        TableView(customRowHeight: 48, hasSeparator: true, hasHeader: false, allowsMultipleSelection: true,
                  items: allCreditCards, columns: Self.creditCardsColumns, creationRowTitle: nil, onSelectionChanged: onSelectionChanged, onDoubleTap: onDoubleTap)
        .frame(width: 526)
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
        self.cardDate = creditCard.formattedDate
        super.init()
        self.text = creditCard.cardDescription
        self.topTextFieldValue = creditCard.obfuscatedNumber
        self.botTextFieldValue = creditCard.cardHolder
        self.topTextFieldPlaceholder = "Card Number"
        self.botTextFieldPlaceholder = "Cardholder"
    }

    override func loadRemoteFavIcon(completion: @escaping (NSImage) -> Void) {
        let icon = NSImage(named: "preferences-credit_card")!
        icon.isTemplate = true
        completion(icon)
    }
}
