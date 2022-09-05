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
    @Environment(\.isCompactContentView) var compactDesign

    let sections: [SectionShortcuts] = [.browser, .editor]

    var body: some View {
        VStack(alignment: .trailing, spacing: compactHeight ? 20 : 40) {
            if !compactHeight || compactDesign {
                Spacer()
            }
            ScrollView {
                DynamicStack(isVertical: compactDesign, horizontalAlignment: .center, verticalAlignment: .top, spacing: compactDesign ? 20 : 40) {
                    ForEach(sections, id: \.self) {
                        SectionFeaturesView(section: $0, width: compactDesign ? nil : 370)
                    }
                }.padding(.horizontal)
            }
            .frame(maxHeight: compactDesign ? .infinity : 550) // enough to fit all the shorcuts, might change over time
            ActionableButton(text: "Done", defaultState: .normal, variant: .primaryBlue) {
                navigateBack()
            }
            Spacer()
        }
        .padding(.horizontal, compactDesign ? 52 : 0)
        .animation(.default, value: compactHeight)
        .animation(.default, value: compactDesign)
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

    private func navigateBack() {
        state.navigateBackFromShortcuts()
    }
}

struct DiscoverShortcutsView_Previews: PreviewProvider {
    static var previews: some View {
        DiscoverShortcutsView()
    }
}

struct DynamicStack<Content: View>: View {

    var isVertical = false
    var horizontalAlignment = HorizontalAlignment.center
    var verticalAlignment = VerticalAlignment.center
    var spacing: CGFloat?
    @ViewBuilder var content: () -> Content

    var body: some View {
        if isVertical {
            VStack(alignment: horizontalAlignment, spacing: spacing, content: content)
        } else {
            HStack(alignment: verticalAlignment, spacing: spacing, content: content)
        }
    }
}
