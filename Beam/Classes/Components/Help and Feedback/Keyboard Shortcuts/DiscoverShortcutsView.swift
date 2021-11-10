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
        VStack(alignment: .trailing, spacing: compactHeight ? 20 : 40) {
            if !compactHeight {
                Spacer()
            }
            ScrollView {
                HStack(alignment: .top, spacing: compactWidth ? 40 : 60) {
                    ForEach(sections, id: \.self) {
                        SectionFeaturesView(section: $0)
                    }
                }
            }
            .frame(maxHeight: 550) // enough to fit all the shorcuts, might change over time
            ActionableButton(text: "Done", defaultState: .normal, variant: .primaryBlue) {
                navigateToJournal()
            }
            Spacer()
        }
        .animation(.default, value: compactHeight)
        .animation(.default, value: compactWidth)
        .background(KeyEventHandlingView(handledKeyCodes: [.enter, .escape], firstResponder: true, onKeyDown: { _ in
            navigateToJournal()
        }))
    }

    private var compactHeight: Bool {
        if state.windowFrame.size.height < 720 {
            return true
        }
        return false
    }

    private var compactWidth: Bool {
        if state.windowFrame.size.width < 810 {
            return true
        }
        return false
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
