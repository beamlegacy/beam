//
//  OmniboxV2ClearButton.swift
//  Beam
//
//  Created by Remi Santos on 24/11/2021.
//

import SwiftUI

struct OmniboxV2ClearButton: View {
    @State private var isHovering = false
    @State private var isTouching = false
    var body: some View {
        Icon(name: "tabs-close_xs", color: (isHovering ? BeamColor.Generic.text : BeamColor.LightStoneGray).swiftUI)
            .blendModeLightMultiplyDarkScreen()
            .frame(width: 18, height: 18)
            .background(Circle()
                            .fill((isTouching ? BeamColor.Mercury : BeamColor.Nero).swiftUI)
                            .blendModeLightMultiplyDarkScreen()
            )
            .onHover { isHovering = $0 }
            .onTouchDown { isTouching = $0 }

    }
}

struct OmniboxV2ClearButton_Previews: PreviewProvider {
    static var previews: some View {
        OmniboxV2ClearButton()
    }
}
