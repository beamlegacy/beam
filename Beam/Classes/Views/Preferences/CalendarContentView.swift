//
//  CalendarContentView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 27/07/2022.
//

import SwiftUI

struct CalendarContent: View {
    @ObservedObject var viewModel: AccountsViewModel

    var body: some View {
        VStack(alignment: .leading) {
            if !viewModel.accountsCalendar.isEmpty {
                VStack(alignment: .leading) {
                    VStack(alignment: .leading) {
                        ForEach(viewModel.accountsCalendar) { account in
                            calendarAccountView(account: account) {
                                viewModel.calendarManager.disconnect(from: account.service, sourceId: account.sourceId)
                                viewModel.accountsCalendar.removeAll(where: { $0 === account })
                            }
                        }
                    }.padding(.bottom, 20)
                }
            }
            Menu("Connect Calendars & Contacts") {
                Button("macOS Calendar…") {
                    connectCalendar(service: .appleCalendar)
                }
                .disabled(viewModel.calendarManager.isConnected(calendarService: .appleCalendar))
                Button("Google Calendar…") {
                    connectCalendar(service: .googleCalendar)
                }
            }
            .font(BeamFont.regular(size: 13).swiftUI)
            .fixedSize()
            Settings.SubtitleLabel("Connect your Calendars & Contacts and easily take meeting notes.")
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
    }

    @ViewBuilder
    private func calendarAccountView(account: AccountCalendar, onDisconnect: (() -> Void)?) -> some View {
        switch account.service {
        case .googleCalendar:
            GoogleAccountView(viewModel: viewModel, account: account, onDisconnect: onDisconnect)
        case .appleCalendar:
            AppleAccountView(viewModel: viewModel, account: account, onDisconnect: onDisconnect)
        }
    }

    private func connectCalendar(service: CalendarServices) {
        viewModel.calendarManager.requestAccess(from: service) { connected in
            if connected { viewModel.calendarManager.updated = true }
        }
    }
}

struct GoogleAccountView: View {
    @ObservedObject var viewModel: AccountsViewModel
    var account: AccountCalendar
    var onDisconnect: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                Text(account.name)
                    .frame(width: 227, alignment: .topLeading)
                    .padding(.trailing, 12)
                if viewModel.calendarManager.connectedSources.first(where: { $0.id == account.sourceId })?.inNeedOfPermission ?? true {
                    Button {
                        onDisconnect?()
                        viewModel.calendarManager.requestAccess(from: .googleCalendar) { connected in
                            if connected { viewModel.calendarManager.updated = true }
                        }
                    } label: {
                        Text("Fix Permissions...")
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                            .frame(width: 125)
                            .padding(.top, -4)
                    }
                } else {
                    Button {
                        UserAlert.showMessage(message: "Are you sure you want to disconnect your Google account?",
                                              informativeText: "You’ll need to add it again to sync your Google Calendars and Contacts.",
                                              buttonTitle: "Disconnect",
                                              secondaryButtonTitle: "Cancel",
                                              buttonAction: {
                            onDisconnect?()
                        })
                    } label: {
                        Text("Disconnect")
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                            .frame(width: 99)
                            .padding(.top, -4)
                    }
                }
            }.padding(.bottom, -5)
            if viewModel.calendarManager.connectedSources.first(where: { $0.id == account.sourceId })?.inNeedOfPermission ?? true {
                Text("Fix permissions to sync...")
                    .font(BeamFont.regular(size: 11).swiftUI)
                    .foregroundColor(BeamColor.Shiraz.swiftUI)
            } else {
                Settings.SubtitleLabel("\(account.nbrOfCalendar) calendars.")
            }

        }
    }
}

struct AppleAccountView: View {
    @ObservedObject var viewModel: AccountsViewModel
    var account: AccountCalendar
    var onDisconnect: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                Text(account.name)
                    .frame(width: 227, alignment: .topLeading)
                    .padding(.trailing, 12)
                if viewModel.calendarManager.connectedSources.first(where: { $0.id == account.sourceId })?.inNeedOfPermission ?? true {
                    Button {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Text("Open Preferences...")
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                            .padding(.top, -4)
                    }
                } else {
                    Button {
                        UserAlert.showMessage(message: "Are you sure you want to disconnect your calendar?",
                                              buttonTitle: "Disconnect",
                                              secondaryButtonTitle: "Cancel",
                                              buttonAction: {
                            onDisconnect?()
                        })
                    } label: {
                        Text("Disconnect")
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                            .frame(width: 99)
                            .padding(.top, -4)
                    }
                }
            }.padding(.bottom, -5)
            if viewModel.calendarManager.connectedSources.first(where: { $0.id == account.sourceId })?.inNeedOfPermission ?? true {
                Text("Fix permissions in System Preferences...")
                    .font(BeamFont.regular(size: 11).swiftUI)
                    .foregroundColor(BeamColor.Shiraz.swiftUI)
            } else {
                Settings.SubtitleLabel("\(account.nbrOfCalendar) calendars.")
            }
        }
    }
}
