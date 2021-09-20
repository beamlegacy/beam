//
//  KeyboardFeature.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 16/09/2021.
//

import Foundation

struct KeyboardFeature: Hashable {
    let name: String
    let shortcuts: [Shortcut]
    let separationString: String?
    let prefix: String?

    internal init(name: String, shortcuts: [Shortcut], separationString: String? = nil, prefix: String? = nil) {
        self.name = name
        self.shortcuts = shortcuts
        self.separationString = separationString
        self.prefix = prefix
    }

    static var demoFeatures: [ KeyboardFeature] {
        [KeyboardFeature(name: "Collect the web", shortcuts: [.init(modifiers: [.option], keys: [])], prefix: "hold"),
         KeyboardFeature(name: "Save Page", shortcuts: [.init(modifiers: [.command], keys: [.string("S")])]),
         KeyboardFeature(name: "Reopen Last Closed tab", shortcuts: [.init(modifiers: [.command], keys: [.string("Z")]),
                                                                     .init(modifiers: [.shift, .command], keys: [.string("T")])], separationString: "and"),
         KeyboardFeature(name: "Jump to Specific Tab", shortcuts: [.init(modifiers: [.command], keys: [.string("1")]),
                                                                   .init(modifiers: [.command], keys: [.string("8")])], separationString: "to"),
        ]
    }
}
