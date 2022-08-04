//
//  SettingTab.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 28/07/2022.
//

import Foundation
import SwiftUI

public enum SettingTab: String, CaseIterable {
    case general, browser, notes, privacy, passwords, accounts, about, beta, advanced, editor

    var label: String {
        switch self {
        case .general:  return "General"
        case .accounts: return "Account"
        case .about: return "About"
        case .browser: return "Browser"
        case .notes: return "Notes"
        case .privacy: return "Privacy"
        case .passwords: return "Passwords"
        case .beta: return "Beta"
        case .advanced: return "Advanced"
        case .editor: return "Editor UI Debug"
        }
    }

    var imageName: String {
        switch self {
        case .general:  return "preferences-general-on"
        case .accounts: return "preferences-account"
        case .about: return "preferences-about"
        case .browser: return "preferences-browser"
        case .notes: return "preferences-cards"
        case .privacy: return "preferences-privacy"
        case .passwords: return "preferences-passwords"
        case .beta: return "preferences-developer"
        case .advanced: return "preferences-developer"
        case .editor: return "preferences-editor-debug"
        }
    }

    var view: NSView {
        switch self {
        case .general: return NSHostingView(rootView: GeneralPreferencesView().fixedSize())
        case .browser: return NSHostingView(rootView: BrowserPreferencesView(viewModel: BrowserPreferencesViewModel()).fixedSize())
        case .notes: return NSHostingView(rootView: NotesPreferencesView().fixedSize())
        case .privacy: return NSHostingView(rootView: PrivacyPreferencesView().fixedSize())
        case .passwords: return NSHostingView(rootView: PasswordsPreferencesView(passwordsViewModel: PasswordListViewModel(), creditCardsViewModel: CreditCardListViewModel()).fixedSize())
        case .accounts: return NSHostingView(rootView: AccountsView(viewModel: AccountsViewModel(calendarManager: BeamData.shared.calendarManager)).fixedSize())
        case .about: return NSHostingView(rootView: AboutPreferencesView().fixedSize())
        case .beta: return NSHostingView(rootView: BetaPreferencesView(viewModel: BetaPreferencesViewModel()).environment(\.managedObjectContext, CoreDataManager.shared.mainContext).fixedSize())
        case .advanced: return NSHostingView(rootView: AdvancedPreferencesView().environment(\.managedObjectContext, CoreDataManager.shared.mainContext).fixedSize())
        case .editor: return NSHostingView(rootView: EditorDebugPreferencesView().fixedSize())
        }
    }

    static func settingTab(for identifier: String) -> SettingTab? {
        let selectedItem = SettingTab.allCases.first { $0.label == identifier }
        return selectedItem
    }

    static var userSettings: [SettingTab] {
        return [.general, .browser, .notes, .privacy, .passwords, .accounts, .about, .beta]
    }

    static var privateSettings: [SettingTab] {
        return [.advanced, .editor]
    }
}
