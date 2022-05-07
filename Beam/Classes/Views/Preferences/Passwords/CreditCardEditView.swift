//
//  CreditCardEditView.swift
//  Beam
//
//  Created by Frank Lefebvre on 02/05/2022.
//

import SwiftUI

struct CreditCardEditView: View {
    let entry: CreditCardEntry?
    let onSubmit: (CreditCardEntry?) -> Void

    @State private var editedEntry = CreditCardEntry(cardDescription: "", cardNumber: "", cardHolder: "", expirationMonth: 0, expirationYear: 0)
    @State private var cardNumber = ""
    @State private var expirationDate = ""

    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        VStack {
            SubmitHandler(action: saveAndDismiss) {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Description:")
                            .font(BeamFont.regular(size: 12).swiftUI)
                            .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                            .frame(width: 96, alignment: .trailing)
                        TextField("", text: $editedEntry.cardDescription)
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                            .frame(width: 286, height: 19, alignment: .center)
                    }
                    .padding(.bottom, 10)
                    HStack {
                        Text("Card Holder:")
                            .font(BeamFont.regular(size: 12).swiftUI)
                            .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                            .frame(width: 96, alignment: .trailing)
                        TextField("", text: $editedEntry.cardHolder)
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                            .frame(width: 286, height: 19, alignment: .center)
                    }
                    .padding(.bottom, 10)
                    HStack {
                        Text("Card Number:")
                            .font(BeamFont.regular(size: 12).swiftUI)
                            .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                            .frame(width: 96, alignment: .trailing)
                        TextField("", text: $cardNumber, onCommit: {
                            cardNumber = editedEntry.formattedNumber
                        })
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .frame(width: 210, height: 19, alignment: .center)
                        .onChange(of: cardNumber) { newValue in
                            editedEntry.cardNumber = String(newValue.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) })
                        }
                        Image(systemName: editedEntry.isValidNumber ? "checkmark.circle" : "exclamationmark.circle")
                            .font(BeamFont.regular(size: 12).swiftUI)
                            .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                        Text(presentedCardType)
                            .font(BeamFont.regular(size: 12).swiftUI)
                            .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                            .frame(width: 110, alignment: .leading)
                    }
                    .padding(.bottom, 10)
                    HStack {
                        Text("Expiration Date:")
                            .font(BeamFont.regular(size: 12).swiftUI)
                            .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                            .frame(width: 96, alignment: .trailing)
                        TextField("", text: $expirationDate, onCommit: {
                            expirationDate = editedEntry.formattedDate
                        })
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .frame(width: 80, height: 19, alignment: .center)
                        .onChange(of: expirationDate) { _ in
                            if let (month, year) = decodedExpirationDate {
                                editedEntry.expirationMonth = month
                                editedEntry.expirationYear = year
                            }
                        }
                        Image(systemName: decodedExpirationDate != nil ? "checkmark.circle" : "exclamationmark.circle")
                            .font(BeamFont.regular(size: 12).swiftUI)
                            .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                    }
                    .padding(.bottom, 10)
                    .padding(.bottom, 12)
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .foregroundColor(BeamColor.Generic.text.swiftUI)
                        }
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.cancelAction)
                        Button {
                            saveAndDismiss()
                        } label: {
                            Text(entry == nil ? "Add Card" : "Done")
                                .foregroundColor(BeamColor.Generic.text.swiftUI)
                        }
                        .buttonStyle(.bordered)
                        .disabled(editedEntry.cardHolder.isEmpty || cardNumber.isEmpty)
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(20)
            }
        }
        .onAppear {
            if let entry = entry {
                editedEntry = entry
                cardNumber = entry.formattedNumber
                expirationDate = entry.formattedDate
            }
        }
    }

    private var decodedExpirationDate: (Int, Int)? {
        let components = expirationDate.components(separatedBy: "/")
        guard components.count == 2, let month = Int(components[0]), var year = Int(components[1]) else { return nil }
        guard month >= 1, month <= 12, year >= 0 else { return nil }
        if year < 100 {
            if year < 22 {
                year += 2100
            } else {
                year += 2000
            }
        }
        if year < 2022 { return nil }
        return (month, year)
    }

    private var presentedCardType: String {
        switch editedEntry.cardType {
        case .visa:
            return "Visa"
        case .masterCard:
            return "Master Card"
        case .amex:
            return "American Express"
        case .discover:
            return "Discover"
        case .diners:
            return "Diner's Card"
        case .jcb:
            return "JCB"
        case .unknown:
            return ""
        }
    }

    private func saveAndDismiss() {
        onSubmit(editedEntry)
        dismiss()
    }

    private func dismiss() {
        presentationMode.wrappedValue.dismiss()
    }
}

private struct SubmitHandler<Content: View>: View {
    var action: () -> Void
    @ViewBuilder var view: () -> Content

    @ViewBuilder
    var body: some View {
        if #available(macOS 12.0, *) {
            Form {
                view()
            }
            .onSubmit(action)
        } else {
            view()
        }
    }
}
