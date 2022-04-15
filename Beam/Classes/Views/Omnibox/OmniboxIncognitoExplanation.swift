//
//  OmniboxIncognitoExplanation.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 08/04/2022.
//

import SwiftUI
import BeamCore

struct OmniboxIncognitoExplanation: View {
    var body: some View {
        VStack(spacing: 0) {
            Separator(horizontal: true)
            VStack(alignment: .leading, spacing: 6) {
                Text(loc("You’re Incognito"))
                    .font(BeamFont.regular(size: 17).swiftUI)
                Text(loc("beam will keep your browsing history private for all tabs in this window.\nAfter your close this window, beam won’t remember the pages you visited, your search history or your autofill information."))
                    .font(BeamFont.light(size: 14).swiftUI)
                    .lineSpacing(3)
            }
            .foregroundColor(BeamColor.Corduroy.swiftUI)
            .padding(30)
        }
    }
}

struct OmniboxIncognitoExplanation_Previews: PreviewProvider {
    static var previews: some View {
        OmniboxIncognitoExplanation()
    }
}
