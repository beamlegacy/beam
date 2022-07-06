//
//  DiscoverShortcutsView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 16/09/2021.
//

import SwiftUI

struct DiscoverShortcutsView: View {

    @EnvironmentObject var state: BeamState
    @EnvironmentObject var windowInfo: BeamWindowInfo

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
                navigateBack()
            }
            Spacer()
        }
        .animation(.default, value: compactHeight)
        .animation(.default, value: compactWidth)
        .background(KeyEventHandlingView(handledKeyCodes: [.enter, .escape], firstResponder: true, onKeyDown: { _ in
            navigateBack()
        }))
    }

    private var compactHeight: Bool {
        if windowInfo.windowFrame.size.height < 720 {
            return true
        }
        return false
    }

    private var compactWidth: Bool {
        if windowInfo.windowFrame.size.width < 810 {
            return true
        }
        return false
    }

    private func navigateBack() {
        state.navigateBackFromShortcuts()
    }
}

struct DiscoverShortcutsView_Previews: PreviewProvider {
    static var previews: some View {
        DiscoverShortcutsView()
    }
}
