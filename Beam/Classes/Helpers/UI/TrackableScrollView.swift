//
//  TrackableScrollView.swift
//  Beam
//
//  Created by Remi Santos on 27/04/2021.
//
//  Credit to https://medium.com/@maxnatchanon/swiftui-how-to-get-content-offset-from-scrollview-5ce1f84603ec

import SwiftUI

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { }
}

public struct TrackableScrollView<Content>: View where Content: View {
    let axes: Axis.Set
    let showIndicators: Bool
    let enableTracking: Bool
    @Binding var contentOffset: CGFloat
    let content: () -> Content

    private let coordinateSpace = "TrackableScrollViewSpace"

    public init(_ axes: Axis.Set = .vertical,
                showIndicators: Bool = true,
                enableTracking: Bool = true,
                contentOffset: Binding<CGFloat>,
                @ViewBuilder content: @escaping () -> Content) {
        self.axes = axes
        self.showIndicators = showIndicators
        self.enableTracking = enableTracking
        self._contentOffset = contentOffset
        self.content = content
    }

    public var body: some View {
            ScrollView(self.axes, showsIndicators: self.showIndicators) {
                ZStack(alignment: self.axes == .vertical ? .top : .leading) {
                    if enableTracking {
                        GeometryReader { insideProxy in
                            Color.clear
                                .preference(key: ScrollOffsetPreferenceKey.self,
                                            value: self.calculateContentOffset(insideProxy: insideProxy))
                        }.frame(width: 0, height: 0)
                    }
                    VStack {
                        content()
                    }
                }
            }
            .coordinateSpace(name: coordinateSpace)
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                guard value != self.contentOffset else { return }
                DispatchQueue.main.async {
                    self.contentOffset = value
                }
            }
    }

    private func calculateContentOffset(insideProxy: GeometryProxy) -> CGFloat {
        var value: CGFloat
        if axes == .vertical {
            value = -insideProxy.frame(in: .named(coordinateSpace)).minY
        } else {
            value = -insideProxy.frame(in: .named(coordinateSpace)).minX
        }
        return (value * 1000).rounded(.toNearestOrEven) / 1000
    }
}
