//
//  WhiteListModalView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 03/06/2021.
//

import SwiftUI
import BeamCore

struct AllowListModalView: View {
    @Environment(\.presentationMode) var presentationMode

    @ObservedObject var viewModel: AllowListViewModel

    @State private var searchString: String = ""
    @State private var selectedItems = [RBAllowlistEntry]()
    @State private var stepperTest: Double = 0.0
    @State private var creationRowTitle: String?

    var body: some View {
        VStack(alignment: .center) {
            HStack {
                Text("Whitelisted sites are excluded from blockers.")
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    Spacer()
                    .font(BeamFont.medium(size: 13).swiftUI)
                SearchBar(text: $searchString).frame(width: 217)
            }
            Spacer()
            AllowListTableView(viewModel: viewModel, searchStr: searchString, selectedItems: $selectedItems, creationRowTitle: $creationRowTitle)
                .frame(width: 526, height: 278, alignment: .center)
                .border(BeamColor.Mercury.swiftUI, width: 1)
                .background(BeamColor.Generic.background.swiftUI)
                .onAppear {
                    viewModel.refreshAllAllowListItems()
                }
            Spacer()
            HStack {
                Button {
                    self.creationRowTitle = "Enter URL"
                } label: {
                    Image("basicAdd")
                        .renderingMode(.template)
                        .foregroundColor(BeamColor.Generic.background.swiftUI)
                }.buttonStyle(BorderedButtonStyle())
                Button {
                    if selectedItems.count > 0 {
                        ContentBlockingManager.shared.radBlockPreferences.remove(entries: selectedItems) {
                            selectedItems.removeAll()
                            viewModel.refreshAllAllowListItems()
                        }
                    }
                } label: {
                    Image("basicRemove")
                        .renderingMode(.template)
                        .foregroundColor(BeamColor.Generic.background.swiftUI)
                }.buttonStyle(BorderedButtonStyle())
                Spacer()
                Button(action: {
                    dismiss()
                }, label: {
                    Text("Cancel")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .frame(maxWidth: .infinity)
                        .frame(width: 62, height: 20, alignment: .center)
                })
                .buttonStyle(BorderedButtonStyle())
                .foregroundColor(BeamColor.Generic.background.swiftUI)
                Button(action: {
                    save()
                }, label: {
                    Text("Save")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .frame(maxWidth: .infinity)
                        .frame(width: 62, height: 20, alignment: .center)
                })
                .buttonStyle(BorderedButtonStyle())
                .foregroundColor(BeamColor.Generic.background.swiftUI)

            }
        }.foregroundColor(BeamColor.Generic.background.swiftUI)
        .padding()
    }

    private func dismiss() {
        presentationMode.wrappedValue.dismiss()
    }

    private func save() {
        viewModel.save()
        presentationMode.wrappedValue.dismiss()
    }
}

struct AllowListModalView_Previews: PreviewProvider {
    static var previews: some View {
        AllowListModalView(viewModel: AllowListViewModel()).frame(width: 568, height: 422, alignment: .center
        )
    }
}
