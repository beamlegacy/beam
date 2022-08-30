//
//  SplitViewSizeControlView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 23/08/2022.
//

import SwiftUI

struct SplitViewSizeControlView: View {

    weak var state: BeamState?
    let closeAction: (()->Void)?

    var body: some View {
        HStack {
            SplitViewButtonView(iconName: "side-split_onethird") {
                guard let width = state?.associatedWindow?.frame.width else { return }
                setWidth(width / 3)
            }.frame(maxWidth: .infinity)
            SplitViewButtonView(iconName: "side-split_equal") {
                guard let width = state?.associatedWindow?.frame.width else { return }
                setWidth(width / 2)
            }.frame(maxWidth: .infinity)
            SplitViewButtonView(iconName: "side-split_thirdone") {
                guard let width = state?.associatedWindow?.frame.width else { return }
                setWidth(width / 3 * 2)
            }.frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 5)
    }

    private func setWidth(_ width: CGFloat) {
        withAnimation {
            state?.sideNoteWidth = width
        }
        closeAction?()
    }
}

struct SplitViewSizeControlView_Previews: PreviewProvider {
    static var state = BeamState()
    static var previews: some View {
        SplitViewSizeControlView(state: state, closeAction: nil)
    }
}

struct SplitViewButtonView: View {

    let iconName: String
    let action: ()->Void

    @State private var isHovered = false

    var body: some View {
        Image(iconName)
            .foregroundColor(foregroundColor)
            .padding(5)
            .background(background)
            .onHover { h in
                isHovered = h
            }
            .onTapGesture(perform: action)
    }

    private var foregroundColor: Color {
        isHovered ? Color(NSColor.windowBackgroundColor) : Color(NSColor.textColor)
    }
    @ViewBuilder private var background: some View {
        if isHovered {
            Color(NSColor.controlAccentColor).cornerRadius(4)
        }
    }
}

struct SplitViewButtonView_Previews: PreviewProvider {
    static var previews: some View {
        SplitViewButtonView(iconName: "side-split_thirdone") { }
    }
}
