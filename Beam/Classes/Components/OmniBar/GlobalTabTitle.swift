//
//  GlobalTabTitle.swift
//  Beam
//
//  Created by Sebastien Metrot on 30/10/2020.
//

import Foundation
import SwiftUI

struct GlobalTabTitle: View {
    var _cornerRadius = CGFloat(7)
    @EnvironmentObject var state: BeamState
    @ObservedObject var tab: BrowserTab
    @State var hover = false
    @Binding var isEditing: Bool

    var body: some View {
        VStack {
           ZStack {
                RoundedRectangle(cornerRadius: _cornerRadius)
                    .foregroundColor(hover ? Color(.omniboxBackgroundColor) : Color(white: 1, opacity: 0))
                HStack {
                    // fav icon:
                    if let icon = tab.favIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 16, maxHeight: 16)
                    }
                    Text(tab.url?.minimizedHost ?? tab.originalQuery ?? "")
                        .font(.custom("SF-Pro-Text-Heavy", size: 16))
                }

                GeometryReader { geometry in
                    Path { path in
                        let f = CGFloat(tab.estimatedProgress)
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: geometry.size.width * f, y: 0))
                        path.addLine(to: CGPoint(x: geometry.size.width * f, y: geometry.size.height))
                        path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                        path.move(to: CGPoint(x: 0, y: 0))
                    }
                    .fill(tab.isLoading ? Color.accentColor.opacity(0.5): Color.accentColor.opacity(0))
                }
                .frame(idealWidth: 600, maxWidth: .infinity, minHeight: 2, maxHeight: 2)
                .offset(x: 0, y: 10)
                .animation(.easeIn(duration: 0.5))
            }
            .frame(height: 28)
            .onHover { h in
                withAnimation {
                    hover = h
                }
            }
            .onTapGesture {
                // should edit
                isEditing = true
                if let h = tab.url?.host, h.hasSuffix("google.com"), let query = tab.originalQuery {
                    state.searchQuery = query
                } else {
                    state.searchQuery = tab.url?.absoluteString ?? ""
                }
                state.searchQuerySelection = [state.searchQuery.wholeRange]
            }
        }
        .padding(.top, Constants.runningOnBigSur ? 0 : 4)
    }
}
