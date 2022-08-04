//
//  Settings.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 28/07/2022.
//

import Foundation
import SwiftUI

public enum Settings {

    struct SubtitleLabel: View {
        let string: String

        init(_ string: String) {
            self.string = string
        }

        var body: some View {
            Text(string)
                .font(BeamFont.regular(size: 11).swiftUI)
                .foregroundColor(BeamColor.Corduroy.swiftUI)
        }
    }

    struct Container<Content: View>: View {
        private let content: () -> Content
        private let contentWidth: Double

        init(contentWidth: Double, @ViewBuilder content: @escaping () -> Content) {
            self.content = content
            self.contentWidth = contentWidth
        }

        var body: some View {
            VStack(alignment: .leading) {
                content()
            }
            .frame(width: CGFloat(contentWidth), alignment: .leading)
            .padding(.vertical, 20)
        }
    }

    struct Row: View {
        public let hasDivider: Bool
        private let titleContent: () -> AnyView
        private let content: () -> AnyView

        init<TitleContent: View, Content: View>(hasDivider: Bool = false, @ViewBuilder titleContent: @escaping () -> TitleContent, @ViewBuilder content: @escaping () -> Content) {
            self.hasDivider = hasDivider
            self.titleContent = { AnyView(titleContent()) }
            self.content = { AnyView(content()) }
        }

        var body: some View {
            VStack(alignment: .leading) {
                HStack(alignment: .top) {
                    titleContent()
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .frame(width: 250, alignment: .trailing)
                    VStack(alignment: .center) {
                        VStack(alignment: .leading) {
                            content()
                        }
                    }
                }
                if hasDivider {
                    Divider()
                        .frame(height: 20)
                        .padding(.horizontal, 20)
                }
            }
        }
    }
}
