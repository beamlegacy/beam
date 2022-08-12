//
//  BeamControlGroup.swift
//  Beam
//
//  Created by Frank Lefebvre on 05/05/2022.
//

import SwiftUI

struct BeamControlGroup<Content>: View where Content: View {
    let accessibilityIdentifier: String
    let content: () -> Content

    var body: some View {
        if #available(macOS 12.0, *) {
            ControlGroup {
                content()
            }
            .accessibilityIdentifier(accessibilityIdentifier)
        } else {
            Group {
                content()
            }
        }
    }
}
