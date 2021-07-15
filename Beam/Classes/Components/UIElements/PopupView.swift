//
//  PopupView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 08/07/2021.
//

import SwiftUI

struct PopupView<T: View>: ViewModifier {

    struct PopupConfig {
        let alignment: Alignment
        let offset: CGSize
        let zIndex: Double
        let backgroundColor: Color
        let backgroundCornerRadius: CGFloat
        let shadowRadius: CGFloat

        init(alignment: Alignment = .center, offset: CGSize = CGSize.zero, zIndex: Double = 0, backgroundColor: Color = BeamColor.Generic.background.swiftUI, backgroundCornerRadius: CGFloat = 6, shadowRadius: CGFloat = 3) {
            self.alignment = alignment
            self.offset = offset
            self.zIndex = zIndex
            self.backgroundColor = backgroundColor
            self.backgroundCornerRadius = backgroundCornerRadius
            self.shadowRadius = shadowRadius
        }
    }

    var isPresented: Bool
    var popup: T
    let config: PopupConfig

    init(isPresented: Bool, config: PopupConfig = PopupConfig(), @ViewBuilder content: () -> T) {
        self.isPresented = isPresented
        self.popup = content()
        self.config = config
    }

    func body(content: Content) -> some View {
        content
            .overlay(configuredPopup(), alignment: config.alignment)
    }

    @ViewBuilder private func configuredPopup() -> some View {
        if isPresented {
            popup
                .background(config.backgroundColor.shadow(radius: config.shadowRadius))
                .cornerRadius(config.backgroundCornerRadius)
                .shadow(radius: config.shadowRadius)
                .offset(config.offset)
                .zIndex(config.zIndex)
        }
    }
}

struct PopupView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Hello")
            .modifier(PopupView(isPresented: true, content: {
                Color.red
            }))
    }
}

extension View {
    func popup<T: View>(isPresented: Bool, config: PopupView<T>.PopupConfig, @ViewBuilder content: () -> T) -> some View {
        return modifier(PopupView(isPresented: isPresented, config: config, content: content))
    }
}
