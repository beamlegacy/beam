//
//  WhiteListModalView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 03/06/2021.
//

import SwiftUI
import BeamCore

struct AllowListModalView: View {
    @Environment(\.presentationMode) private var presentationMode

    @State var viewModel = AllowListViewModel()
    @State private var searchString: String = ""
    @State private var selectedItems = [AllowListViewItem]()
    @State private var stepperTest: Double = 0.0
    @State private var creationRowTitle: String?

    var body: some View {
        VStack(alignment: .center) {
            HStack {
                Text("Allowed sites are excluded from blockers.")
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                Spacer()
                SearchBar(text: $searchString)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(width: 217)
            }
            AllowListTableView(viewModel: viewModel, searchStr: searchString, selectedItems: $selectedItems, creationRowTitle: $creationRowTitle)
                .border(BeamColor.Generic.tableViewStroke.swiftUI, width: 1)
                .background(BeamColor.Generic.tableViewBackground.swiftUI)
                .onAppear {
                    viewModel.refreshAllAllowListItems()
                }
            HStack {
                Button {
                    self.creationRowTitle = loc("Enter URL", comment: "Table creation row title")
                } label: {
                    Image("basicAdd")
                        .renderingMode(.template)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                }.buttonStyle(BorderedButtonStyle())
                Button {
                    if !selectedItems.isEmpty {
                        viewModel.remove(items: selectedItems)
                    }
                } label: {
                    Image("basicRemove")
                        .renderingMode(.template)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                }.buttonStyle(BorderedButtonStyle())
                    .disabled(selectedItems.isEmpty)
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
                .keyboardShortcut(.cancelAction)
                Button(action: {
                    save()
                }, label: {
                    Text("Apply")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .frame(maxWidth: .infinity)
                        .frame(width: 62, height: 20, alignment: .center)
                })
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
        AllowListModalView().frame(width: 568, height: 422, alignment: .center)
    }
}
