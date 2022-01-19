//
//  ShortcutView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 16/09/2021.
//

import SwiftUI

struct ShortcutView: View {

    let shortcut: Shortcut
    var spacing: Double = 3
    var withBackground = true

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(shortcut.modifiers, id: \.self) { modif in
                modif.symbol(withBackground: withBackground)
            }
            ForEach(shortcut.keys, id: \.self) { key in
                key.symbol(withBackground: withBackground)
            }
        }
    }
}

struct ShortcutView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ShortcutView(shortcut: Shortcut(modifiers: [.shift, .command], keys: [.tab]))
            ShortcutView(shortcut: Shortcut(modifiers: [.shift, .command], keys: [.string("d")]))
            ShortcutView(shortcut: Shortcut(modifiers: [.shift, .command], keys: [.tab]))
                .preferredColorScheme(.dark)
            ShortcutView(shortcut: Shortcut(modifiers: [.shift, .command], keys: [.string("d")]))
                .preferredColorScheme(.dark)
        }
    }
}
