//
//  CreditCardEditView.swift
//  Beam
//
//  Created by Frank Lefebvre on 02/05/2022.
//

import SwiftUI
import BeamCore

fileprivate extension CharacterSet {
    static let charactersInCardHolderName = CharacterSet.alphanumerics.union(.whitespaces)
    static let charactersInCardNumber = CharacterSet(charactersIn: "0123456789 ")
    static let charactersInExpirationDate = CharacterSet(charactersIn: "0123456789/")
}

fileprivate extension String {
    func filteredAsCardHolderName() -> String {
        String(unicodeScalars.filter { CharacterSet.charactersInCardHolderName.contains($0) })
    }

    func filteredAsCardNumber() -> String {
        String(unicodeScalars.filter { CharacterSet.charactersInCardNumber.contains($0) }).truncatedToSignificantLength(19)
    }

    func filteredAsExpirationDate() -> String {
        String(unicodeScalars.filter { CharacterSet.charactersInExpirationDate.contains($0) }).truncatedToSignificantLength(7)
    }

    func filteredAsCanonicalCardNumber() -> String {
        String(unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) })
    }

    private static let digitsAndSpaces = CharacterSet.decimalDigits.union(.whitespaces)

    private func truncatedToSignificantLength(_ maxLength: Int) -> String {
        var characters = Substring(self).unicodeScalars
        repeat {
            let significantCount = characters
                .filter { !CharacterSet.whitespaces.contains($0) }
                .count
            let dropCount = significantCount - maxLength
            if dropCount <= 0 {
                break
            }
            characters = characters.dropLast(dropCount)
        } while true
        return String(characters)
    }
}

struct CreditCardEditView: View {
    let entry: CreditCardEntry?
    let onSubmit: (CreditCardEntry?) -> Bool

    @State private var editedEntry = CreditCardEntry(cardDescription: "", cardNumber: "", cardHolder: "", expirationMonth: 0, expirationYear: 0)
    @State private var cardNumber = ""
    @State private var expirationDate = ""
    @State private var editingCardDescription = false
    @State private var editingCardHolder = false
    @State private var editingCardNumber = false
    @State private var editingExpirationDate = false
    @State private var currentMonth = 0
    @State private var currentYear = 0
    @State private var showingDuplicateAlert = false

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
                        BoxedTextFieldView(title: "", text: $editedEntry.cardDescription, isEditing: $editingCardDescription, onEscape: dismiss)
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                            .frame(width: 286, height: 19, alignment: .center)
                    }
                    .padding(.bottom, 10)
                    HStack {
                        Text("Card Holder:")
                            .font(BeamFont.regular(size: 12).swiftUI)
                            .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                            .frame(width: 96, alignment: .trailing)
                        BoxedTextFieldView(title: "", text: $editedEntry.cardHolder, isEditing: $editingCardHolder, textWillChange: { proposedText in
                            (proposedText.filteredAsCardHolderName(), nil)
                        }, onEscape: dismiss)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .frame(width: 286, height: 19, alignment: .center)
                    }
                    .padding(.bottom, 10)
                    HStack {
                        Text("Card Number:")
                            .font(BeamFont.regular(size: 12).swiftUI)
                            .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                            .frame(width: 96, alignment: .trailing)
                        BoxedTextFieldView(title: "", text: $cardNumber, isEditing: $editingCardNumber, textWillChange: { proposedText in
                            (proposedText.filteredAsCardNumber(), nil)
                        }, onEscape: dismiss)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .frame(width: 210, height: 19, alignment: .center)
                        .onChange(of: cardNumber) { newValue in
                            editedEntry.cardNumber = newValue.filteredAsCanonicalCardNumber()
                        }
                        .onChange(of: editingCardNumber) { editing in
                            if !editing {
                                cardNumber = editedEntry.formattedNumber
                            }
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
                        BoxedTextFieldView(title: "MM/YYYY", text: $expirationDate, isEditing: $editingExpirationDate, textWillChange: { proposedText in
                            (proposedText.filteredAsExpirationDate(), nil)
                        }, onEscape: dismiss)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .frame(width: 80, height: 19, alignment: .center)
                        .onChange(of: expirationDate) { _ in
                            if let (month, year) = decodedExpirationDate {
                                editedEntry.expirationMonth = month
                                editedEntry.expirationYear = year
                            } else {
                                editedEntry.expirationMonth = 0
                                editedEntry.expirationYear = 0
                            }
                        }
                        .onChange(of: editingExpirationDate) { editing in
                            if !editing {
                                expirationDate = editedEntry.formattedDate
                            }
                        }
                        Image(systemName: decodedExpirationDate != nil ? "checkmark.circle" : "exclamationmark.circle")
                            .font(BeamFont.regular(size: 12).swiftUI)
                            .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                        Text(editedEntry.expirationDateStatus(currentMonth: currentMonth, currentYear: currentYear) == .expired ? "Expired" : "")
                            .font(BeamFont.regular(size: 12).swiftUI)
                            .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                            .frame(alignment: .leading)
                    }
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
                        }
                        .buttonStyle(.bordered)
                        .disabled(editedEntry.cardHolder.isEmpty || !editedEntry.isValidNumber || editedEntry.expirationDateStatus(currentMonth: currentMonth, currentYear: currentYear) != .valid)
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(20)
            }
        }
        .fixedSize()
        .alert(isPresented: $showingDuplicateAlert) {
            Alert(title: Text("There is already a credit card with the same number and expiration date."))
        }
        .onAppear {
            if let entry = entry {
                editedEntry = entry
                cardNumber = entry.formattedNumber
                expirationDate = entry.formattedDate
            }
            let calendar = Calendar(identifier: .gregorian) // We are dealing with credit card expiration dates, best to use Gregorian calendar regardless of locale.
            let components = calendar.dateComponents(in: .current, from: BeamDate.now)
            if let month = components.month, let year = components.year {
                currentMonth = month
                currentYear = year
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
        if year < 2000 { return nil }
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
        if onSubmit(editedEntry) {
            dismiss()
        } else {
            showingDuplicateAlert = true
        }
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
