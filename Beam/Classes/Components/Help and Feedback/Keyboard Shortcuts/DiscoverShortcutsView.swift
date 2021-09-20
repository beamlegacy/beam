//
//  DiscoverShortcutsView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 16/09/2021.
//

import SwiftUI

struct DiscoverShortcutsView: View {

    @EnvironmentObject var state: BeamState

    let sections: [SectionShortcuts] = [.browser, .editor]

    var body: some View {
        VStack(spacing: 40) {
            HStack(alignment: .top, spacing: 60.0) {
                ForEach(sections, id: \.self) {
                    SectionFeaturesView(section: $0)
                }
            }
            HStack {
                Spacer()
                ActionableButton(text: "Done", defaultState: .normal, variant: .primaryBlue) {
                    navigateToJournal()
                }
                .frame(width: 89)
            }
        }
        .padding(.top, 60)
        .background(KeyEventHandlingView(handledKeyCodes: [.enter, .escape], firstResponder: true, onKeyDown: { _ in
            navigateToJournal()
        }))
    }

    private func navigateToJournal() {
        state.navigateToJournal(note: nil)
    }
}

struct DiscoverShortcutsView_Previews: PreviewProvider {
    static var previews: some View {
        DiscoverShortcutsView()
    }
}
