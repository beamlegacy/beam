//
//  UserInformationsModalView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 07/07/2021.
//

import Foundation
import SwiftUI

struct UserInformationsModalView: View {
    @Environment(\.presentationMode) var presentationMode

    @State var showingUserInformationsEdit = false
    @State var showingUserInformationsAdd = false
    @State var userInfoIsSelected = false
    @State private var selectedEntries = IndexSet()
    @State var selectedUserInfo: UserInformations?

    var userInformations: [UserInformations]

    var body: some View {
        VStack {
            HStack {
                Text("Addresses")
                    .font(BeamFont.semibold(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .padding(20)
                Spacer()
            }
            VStack {
                UserInformationsTableView(adresseIsSelected: $userInfoIsSelected, userInformations: userInformations, onSelectionChanged: { idx in
                    DispatchQueue.main.async {
                        self.selectedEntries = idx
                        guard let selectedIdx = selectedEntries.last else {
                            return
                        }
                        selectedUserInfo = userInformations[selectedIdx]
                        userInfoIsSelected = idx.count > 0
                    }
                })
                .frame(width: 398, height: 242, alignment: .center)
                .border(BeamColor.Mercury.swiftUI, width: 1)
                .background(BeamColor.Generic.background.swiftUI)
                HStack {
                    Button {
                        self.showingUserInformationsAdd.toggle()
                    } label: {
                        Image("basicAdd")
                            .renderingMode(.template)
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                    }.buttonStyle(BorderedButtonStyle())
                    .sheet(isPresented: $showingUserInformationsAdd) {
                        UserInformationsEditModalView(country: "",
                                                      organization: "",
                                                      firstName: "", lastName: "",
                                                      postalCode: "", city: "",
                                                      phone: "", email: "",
                                                      adress: "") { _ in
                            // VIEWMODEL ADD USERINFO
                        }
                            .frame(width: 440, height: 469, alignment: .center)
                    }
                    Button {
                        removeEntry()
                    } label: {
                        Image("basicRemove")
                            .renderingMode(.template)
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                    }.buttonStyle(BorderedButtonStyle())
                    .disabled(!userInfoIsSelected)

                    Button {
                        self.showingUserInformationsEdit.toggle()
                    } label: {
                        Text("Edit...")
                            .font(BeamFont.regular(size: 13).swiftUI)
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                    }.buttonStyle(BorderedButtonStyle())
                    .disabled(!userInfoIsSelected)
                    .sheet(isPresented: $showingUserInformationsEdit) {
                        UserInformationsEditModalView(country: "LOLOLOL",
                                                      organization: selectedUserInfo?.organization ?? "",
                                                      firstName: selectedUserInfo?.firstName ?? "", lastName: selectedUserInfo?.lastName ?? "",
                                                      postalCode: selectedUserInfo?.postalCode ?? "",
                                                      city: selectedUserInfo?.city ?? "",
                                                      phone: selectedUserInfo?.phone ?? "", email: selectedUserInfo?.email ?? "",
                                                      adress: selectedUserInfo?.adresses ?? "") { _ in
                            // VIEWMODEL UPDATE USERINFO
                        }
                            .frame(width: 440, height: 469, alignment: .center)
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(BeamFont.regular(size: 13).swiftUI)
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                    }.buttonStyle(BorderedButtonStyle())
                }.padding(.vertical, 20)
            }
            .frame(width: 398, alignment: .center)
        }
    }

    private func removeEntry() {
        if self.selectedEntries.first != nil {
            // ViewModel remove UserInfo
        }
    }

    private func dismiss() {
        presentationMode.wrappedValue.dismiss()
    }
}

struct UserInformationsModalView_Previews: PreviewProvider {
    static var previews: some View {
        UserInformationsModalView(userInformations: MockUserInformationsStore().fetchAll())
    }
}

struct UserInformationsTableView: View {
    @State private var allUserInformationsItems = [UserInformationsTableViewItem]()
    @Binding var adresseIsSelected: Bool

    var adressesColumns = [
        TableViewColumn(key: "userInfo", title: "UserInformation", sortable: false, resizable: false, width: 398, fontSize: 11)
    ]
    var userInformations: [UserInformations]
    var onSelectionChanged: (IndexSet) -> Void

    var body: some View {
        TableView(customRowHeight: 37, hasSeparator: true, hasHeader: false, allowsMultipleSelection: false,
                  items: allUserInformationsItems, columns: adressesColumns, creationRowTitle: nil, shouldReloadData: .constant(nil)) { (_, _) in

        } onSelectionChanged: { idx in
            onSelectionChanged(idx)
        }.onAppear {
            refreshAllUserInformationsItems()
        }
    }

    private func refreshAllUserInformationsItems() {
        for userInfo in userInformations {
            allUserInformationsItems.append(UserInformationsTableViewItem(userInfo: userInfo))
        }
    }
}

struct UserInformationsTableView_Previews: PreviewProvider {
    static var previews: some View {
        UserInformationsTableView(adresseIsSelected: .constant(false), userInformations: [UserInformations( country: 2, organization: "Beam", firstName: "John", lastName: "Beam", adresses: "123 Rue de Beam", postalCode: "69001", city: "BeamCity", phone: "0606060606", email: "john@beamapp.co")]) { _ in}
    }
}

@objcMembers
class UserInformationsTableViewItem: TableViewItem {
    var userInfo: String

    init(userInfo: UserInformations) {
        self.userInfo = "\(userInfo.firstName ?? "") \(userInfo.lastName ?? ""), \(userInfo.adresses ?? "") \(userInfo.postalCode ?? "") \(userInfo.city ?? "") \(userInfo.phone ?? "")"
        super.init()
    }
}
