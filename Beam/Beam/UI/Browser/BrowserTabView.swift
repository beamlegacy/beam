//
//  BroserTabView.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import Foundation
import SwiftUI

struct BrowserTabView: View {
    @EnvironmentObject var state: BeamState
    @ObservedObject var tab: BrowserTab
    @State var showButton = false
    @State var isHovering = false
    var selected: Bool

    static var tabFrameColor = Color("TabFrame")

    var body: some View {
        ZStack {
            if isHovering {
                RoundedRectangle(cornerRadius: 5)
                    .padding(.all, 2)
                    .foregroundColor(Color("TabHover"))

            }

            GeometryReader { geometry in
                Path { path in
                    path.move(to: CGPoint(x: geometry.size.width - 1, y: geometry.size.height * 0.25))
                    path.addLine(to: CGPoint(x: geometry.size.width - 1, y: geometry.size.height * 0.75))
                }
                .stroke(Self.tabFrameColor)
            }
            HStack {
                Button("􀆄") {
                    closeTab(id: tab.id)
                }.opacity(showButton ? 1 : 0)
                .onHover(perform: { v in
                    showButton = v
                })
                .buttonStyle(BorderlessButtonStyle())
                .padding(.leading, 2)

                // fav icon:
                if let icon = tab.favIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 16, maxHeight: 16, alignment: .center)
                }

                Text(tab.title)
                    .padding(.top, 2)
                    .padding([.leading, .trailing], 3)
                    .frame(minWidth: 50, maxWidth: .infinity, minHeight: 20, maxHeight: 20, alignment: .leading)
                    .font(selected ? .system(size: 12, weight: .bold) : .system(size: 12, weight: .regular))
            }.onHover(perform: { hovering in
                isHovering = hovering
            })
        }
        .padding([.trailing], 1)
        .padding([.top], 2)
        .animation(nil)
    }

    func buildTabDecoration(_ path: inout Path, width: Int, height: Int) {
        let radius = Int(2)

        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: 0, y: radius))
        path.addArc(center: CGPoint(x: radius, y: radius),
                    radius: CGFloat(radius),
                    startAngle: Angle(degrees: 180), endAngle: Angle(degrees: -90), clockwise: false)
        path.addLine(to: CGPoint(x: width - radius, y: 0))
        path.addArc(center: CGPoint(x: width - radius, y: radius),
                    radius: CGFloat(radius),
                    startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()

    }

    func closeTab(id: UUID) {
        for (i, t) in state.tabs.enumerated() where t.id == id {
            if i > 0 {
                state.currentTab = state.tabs[i - 1]
            } else if state.tabs.count > 1 {
                state.currentTab = state.tabs[i + 1]
            } else {
                state.currentTab = BrowserTab(state: state, originalQuery: "", note: nil)
                if let note = state.currentNote {
                    state.navigateToNote(note)
                } else {
                    state.navigateToJournal()
                }
            }
            state.tabs.remove(at: i)
        }

    }
}

struct BrowserTabView_Previews: PreviewProvider {
    static var state = BeamState(data: BeamData())
    static var tab = BrowserTab(state: state, originalQuery: "test tab1", note: nil)
    static var previews: some View {
        Group {
            HStack {
                BrowserTabView(tab: tab, selected: false)
                BrowserTabView(tab: tab, selected: true)
                BrowserTabView(tab: tab, selected: false)
            }
        }
    }
}
