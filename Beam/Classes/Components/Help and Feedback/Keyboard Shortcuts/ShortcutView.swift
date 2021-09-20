//
//  ShortcutView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 16/09/2021.
//

import SwiftUI

struct ShortcutView: View {

    let shortcut: Shortcut

    var body: some View {
        HStack(spacing: 3) {
            ForEach(shortcut.modifiers, id: \.self) { modif in
                modif.symbol
            }
            ForEach(shortcut.keys, id: \.self) { key in
                key.symbol
            }
        }
    }
}

struct ShortcutView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ShortcutView(shortcut: Shortcut(modifiers: [.shift, .command], keys: [.tab]))
            ShortcutView(shortcut: Shortcut(modifiers: [.shift, .command], keys: [.string("d")]))
            if #available(macOS 11.0, *) {
                ShortcutView(shortcut: Shortcut(modifiers: [.shift, .command], keys: [.tab]))
                    .preferredColorScheme(.dark)
                ShortcutView(shortcut: Shortcut(modifiers: [.shift, .command], keys: [.string("d")]))
                    .preferredColorScheme(.dark)
            }
        }
    }
}
