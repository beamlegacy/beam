//
//  TextNode+SpellChecking.swift
//  Beam
//
//  Created by Frank Lefebvre on 25/08/2022.
//

import Foundation
import AppKit
import NaturalLanguage
import Combine
import BeamCore

extension TextNode {
    private enum SpellCheckingAction {
        case replace(String)
        case ignoreWord
        case learnWord
    }

    func triggerSpellChecking() {
        guard Persistence.SpellChecking.enable != false, isSpellCheckable else {
            spellCheckingResults.removeAll()
            return
        }
        let text = elementText.text
        let range = elementText.wholeRange
        NSSpellChecker.shared.automaticallyIdentifiesLanguages = true
        NSSpellChecker.shared.requestChecking(of: text, range: NSRange(location: range.lowerBound, length: range.count), types: NSTextCheckingResult.CheckingType.orthography.rawValue | NSTextCheckingResult.CheckingType.spelling.rawValue | NSTextCheckingResult.CheckingType.correction.rawValue, options: nil, inSpellDocumentWithTag: 0) { [weak self] (_, results, orthography, _) in
            guard let self = self else { return }
            DispatchQueue.mainSync {
                self.spellCheckingResults = results
                self.spellCheckingOrthography = orthography
            }
        }
    }

    func displayManualSpellCheckingMenuIfNeeded(at position: Int, event: NSEvent) -> Bool {
        // Check if click pos is in a spell checking range
        guard let editor = editor,
              let index = spellCheckingResultIndex(at: position),
              let spellResult = spellCheckingResult(atIndex: index),
              let guesses = NSSpellChecker.shared.guesses(forWordRange: spellResult.range, in: elementText.text, language: nil, inSpellDocumentWithTag: 0)
        else {
            return false
        }

        let checker = NSSpellChecker.shared
        checker.dismissCorrectionIndicator(for: editor)
        let word = elementText.text.substring(range: (spellResult.range.lowerBound ..< spellResult.range.upperBound))
        let menu = spellCheckingMenu(guesses: guesses) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .replace(let replacement):
                self.cmdManager.replaceText(in: self, for: spellResult.range.lowerBound ..< spellResult.range.upperBound, with: BeamText(replacement))
                self.focus(position: spellResult.range.lowerBound + replacement.count)
                self.root?.cancelSelection(.current)
            case .ignoreWord:
                checker.ignoreWord(word, inSpellDocumentWithTag: 0)
                self.triggerSpellChecking()
                Task.detached {
                    let checker = NSSpellChecker.shared
                    Persistence.SpellChecking.ignoredWords = checker.ignoredWords(inSpellDocumentWithTag: 0)
                }
            case .learnWord:
                checker.learnWord(word)
                self.triggerSpellChecking()
            }
        }
        NSMenu.popUpContextMenu(menu, with: event, for: editor)
        return true
    }

    private func spellCheckingResultIndex(at position: Int) -> Int? { // multiple... how to handle these?
        spellCheckingResults.firstIndex { $0.resultType == .spelling && $0.range.contains(position) }
    }

    private func spellCheckingResult(at position: Int) -> NSTextCheckingResult? {
        if let index = spellCheckingResultIndex(at: position) {
            return spellCheckingResults[index]
        }
        return nil
    }

    private func spellCheckingResult(atIndex index: Int?) -> NSTextCheckingResult? {
        guard let index = index, index < spellCheckingResults.count else { return nil }
        return spellCheckingResults[index]
    }

    private func spellCheckingResultCandidates(at position: Int) -> [NSTextCheckingResult] {
        let candidates = spellCheckingResults.filter {
            $0.range.containsInclusively(position)
        }
        return candidates
    }

    private func spellCheckingMenu(guesses: [String], action: @escaping (SpellCheckingAction) -> Void) -> NSMenu {
        let menu = NSMenu(title: "Spell Checking")
        if guesses.isEmpty {
            let noGuesses = NSMenuItem(title: "No Guesses Found", action: nil, keyEquivalent: "")
            noGuesses.isEnabled = false
            menu.addItem(noGuesses)
        } else {
            for item in guesses {
                menu.addItem(withTitle: item) { _ in
                    action(.replace(item))
                }
            }
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Ignore Spelling") { _ in
            action(.ignoreWord)
        }
        menu.addItem(withTitle: "Learn Spelling") { _ in
            action(.learnWord)
        }
        return menu
    }
}

