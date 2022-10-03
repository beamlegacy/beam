//
//  AppDelegate+SpellChecking.swift
//  Beam
//
//  Created by Beam on 03/10/2022.
//

import Foundation

extension AppDelegate {
    func initializeSpellChecker() {
        if let ignoredWords = Persistence.SpellChecking.ignoredWords {
            NSSpellChecker.shared.setIgnoredWords(ignoredWords, inSpellDocumentWithTag: 0)
        }
    }
}
