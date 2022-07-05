//
//  OtherCreditCardsModal.swift
//  Beam
//
//  Created by Frank Lefebvre on 02/05/2022.
//

import SwiftUI

struct OtherCreditCardsModal: View {
    @ObservedObject var viewModel: CreditCardListViewModel
    var onFill: (CreditCardEntry) -> Void
    var onRemove: ([CreditCardEntry]) -> Void
    var onDismiss: () -> Void

    @State private var showingAlert = false

    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        VStack {
            HStack {
                Text("Choose a credit card")
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .font(BeamFont.medium(size: 13).swiftUI)
                Spacer()
            }
            Spacer()
            CreditCardsTableView(allCreditCards: viewModel.allCreditCardTableViewItems) { idx in
                viewModel.updateSelection(idx)
            } onDoubleTap: { _ in
                guard let selectedEntry = viewModel.selectedEntries.first else { return }
                onFill(selectedEntry)
            }
            .frame(width: 528, height: 240, alignment: .center)
                .border(BeamColor.Mercury.swiftUI, width: 1)
                .background(BeamColor.Generic.background.swiftUI)

            Spacer()
            HStack {
                OtherPasswordModalButton(title: "Remove", isDisabled: viewModel.disableRemoveButton) {
                    self.showingAlert = true
                }
                .alert(isPresented: $showingAlert) {
                    Alert(title: Text(viewModel.alertMessageToDeleteSelectedEntries()),
                          primaryButton: .destructive(Text("Remove"), action: {
                        onRemove(viewModel.selectedEntries)
                    }),
                          secondaryButton: .cancel(Text("Cancel")))
                }
                Spacer()
                HStack {
                    OtherPasswordModalCancelButton(title: "Cancel", isDisabled: false) {
                        dismiss()
                    }
                    OtherPasswordModalButton(title: "Fill", isDisabled: viewModel.disableFillButton) {
                        guard let selectedEntry = viewModel.selectedEntries.first else { return }
                        onFill(selectedEntry)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .foregroundColor(BeamColor.Generic.background.swiftUI)
        .padding(20)
        .opacity(viewModel.isUnlocked ? 1 : 0)
        .onAppear {
            Task {
                await viewModel.checkAuthentication()
                if !viewModel.isUnlocked {
                    dismiss()
                }
            }
        }
    }

    private func dismiss() {
        onDismiss()
        presentationMode.wrappedValue.dismiss()
    }
}

struct OtherCreditCardsSheet: View {
    @ObservedObject var viewModel: CreditCardListViewModel

    var onFill: (CreditCardEntry) -> Void
    var onRemove: ([CreditCardEntry]) -> Void
    var onDismiss: () -> Void

    let width = 568.0
    let height = 361.0

    var body: some View {
        FormatterViewBackground(boxCornerRadius: 10, shadowOpacity: 0) {
            OtherCreditCardsModal(viewModel: viewModel, onFill: onFill, onRemove: onRemove, onDismiss: onDismiss)
                .background(Color.clear)
                .frame(width: width, height: height, alignment: .center)
        }
    }
}
