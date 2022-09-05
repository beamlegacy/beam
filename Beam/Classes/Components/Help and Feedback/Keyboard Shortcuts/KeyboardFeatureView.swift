//
//  KeyboardFeatureView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 16/09/2021.
//

import SwiftUI

struct KeyboardFeatureView: View {

    let feature: KeyboardFeature
    let width: CGFloat?

    var body: some View {
        HStack(spacing: 6) {
            Text(feature.name)
                .font(BeamFont.regular(size: 12).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
            Spacer()
            if let prefix = feature.prefix {
                Text(prefix)
                    .font(BeamFont.regular(size: 12).swiftUI)
                    .foregroundColor(BeamColor.Corduroy.swiftUI)
            }
            ForEach(feature.shortcuts, id: \.self) { shortcut in
                ShortcutView(shortcut: shortcut)
                if let separator = feature.separationString, shortcut != feature.shortcuts.last {
                    Text(separator)
                        .font(BeamFont.regular(size: 10).swiftUI)
                        .foregroundColor(BeamColor.Generic.placeholder.swiftUI)
                }
            }
        }.if(width != nil) {
            $0.frame(width: width!, height: 34)
        }
            .frame(height: 34)
    }
}

struct KeyboardFeatureView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ForEach(KeyboardFeature.demoFeatures, id: \.self) {
                KeyboardFeatureView(feature: $0, width: 370)
            }
        }
        .background(Color.white)
    }
}
