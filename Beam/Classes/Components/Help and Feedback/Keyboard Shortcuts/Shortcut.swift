//
//  Shortcut.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 16/09/2021.
//

import Foundation

struct Shortcut: Hashable {
    let modifiers: [ShortcutModifier]
    let keys: [ShortcutKey]
}
