//
//  ShootCardConfirmationView.swift
//  Beam
//
//  Created by Remi Santos on 08/04/2021.
//

import SwiftUI

struct ShootCardConfirmationView: View {
    @EnvironmentObject var state: BeamState

    static let size = CGSize(width: 170, height: 42)

    var cardName = ""
    var numberOfElements = 1
    var isText = true
    @State private var isVisible = false

    private var iconName: String {
        return isText ? "collect-text" : "collect-generic"
    }
    private var prefixText: String {
        return numberOfElements == 1 ? "Added to " : "\(numberOfElements) Added to "
    }
    var body: some View {
        FormatterViewBackground {
            HStack {
                Icon(name: iconName, size: 16, color: BeamColor.Generic.text.swiftUI)
                Text(prefixText)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .font(BeamFont.medium(size: 13).swiftUI)
                    +
                Text(cardName)
                    .foregroundColor(BeamColor.Beam.swiftUI)
                    .font(BeamFont.regular(size: 13).swiftUI)
            }
            .lineLimit(1)
            .padding(BeamSpacing._100)
            .onTapGesture {
                state.navigateToNote(named: cardName)
            }
        }
        .fixedSize(horizontal: true, vertical: true)
        .zIndex(20)
        .animation(.easeInOut(duration: 0.3))
        .scaleEffect(isVisible ? 1.0 : 0.98)
        .offset(x: 0, y: isVisible ? 0.0 : -4.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.6))
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.3))
        .onAppear {
            isVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
                isVisible = false
            }
        }
    }
}

struct ShootCardConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        ShootCardConfirmationView(cardName: "A Long Card Name", numberOfElements: 4, isText: false)
            .frame(width: 300, height: 70)
    }
}
