//
//  ToggleView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 13/05/2022.
//

import SwiftUI

struct ToggleView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var mouseDown: Bool = false
    @Binding var isOn: Bool

    init(isOn: Binding<Bool>) {
        self._isOn = isOn
    }

    var body: some View {
        var backgroundColor: Color = BeamColor.Bluetiful.swiftUI
        if !isOn {
            switch colorScheme {
            case .light:
                backgroundColor = BeamColor.AlphaGray.swiftUI
            case .dark:
                backgroundColor = mouseDown ? BeamColor.AlphaGray.swiftUI: BeamColor.Mercury.swiftUI
            @unknown default:
                break
            }
        }

        return GeometryReader { reader in
            HStack {
                if isOn {
                    Spacer()
                }
                VStack {
                    Circle()
                        .fill(colorScheme == .light ? Color.white : BeamColor.Niobium.swiftUI)
                        .frame(width: 12, height: 12)
                }.padding(2)
                    .frame(width: reader.frame(in: .global).height)
                if !isOn {
                    Spacer()
                }
            }
            .background(
                ZStack {
                    backgroundColor.blendModeLightMultiplyDarkScreen()
                    if mouseDown {
                        if isOn {
                            BeamColor.Niobium.alpha(0.25).swiftUI
                        } else {
                            colorScheme == .light ? BeamColor.Niobium.alpha(0.15).swiftUI : BeamColor.Niobium.alpha(0.12).swiftUI
                        }
                    }
                })
            .clipShape(Capsule())
            .frame(width: 26, height: 16)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged({ _ in
                        mouseDown = true
                    })
                    .onEnded({ _ in
                        withAnimation {
                            isOn.toggle()
                        }
                        mouseDown = false
                    })
            )
        }
    }
}

struct ToggleView_Previews: PreviewProvider {

    static var previews: some View {
        VStack(spacing: BeamSpacing._200) {
            ToggleView(isOn: .constant(false))
                .frame(width: 26, height: 16)

            ToggleView(isOn: .constant(true))
                .frame(width: 26, height: 16)
        }.frame(width: 80, height: 80, alignment: .center)
    }
}
