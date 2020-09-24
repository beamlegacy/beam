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
    var selected: Bool
    
    static var tabColor = Color(NSColor.lightGray).opacity(0.25)
    static var selectedTabColor = Color(NSColor.gray).opacity(0.25)
    static var tabFrameColor = Color(NSColor.lightGray)
    static var selectedTabFrameColor = Color(NSColor.gray)
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
//                Path { path in
//                    buildTabDecoration(&path, width: Int(geometry.size.width), height: Int(geometry.size.height))
//                }
//                .fill(selected ? Self.selectedTabColor : Self.tabColor)
//                Path { path in
//                    buildTabDecoration(&path, width: Int(geometry.size.width), height: Int(geometry.size.height))
//                }
//                .stroke(selected ? Self.selectedTabFrameColor : Self.tabFrameColor)
                Path { path in
                    path.move(to: CGPoint(x: geometry.size.width - 1, y: geometry.size.height * 0.25))
                    path.addLine(to: CGPoint(x: geometry.size.width - 1, y: geometry.size.height * 0.75))
                }
                .stroke(Self.tabFrameColor)
            }
            HStack {
                Button("X") {
                    for (i,t) in state.tabs.enumerated() {
                        if t.id == tab.id {
                            if i > 0 {
                                state.currentTab = state.tabs[i - 1]
                            } else if state.tabs.count > 1 {
                                state.currentTab = state.tabs[i + 1]
                            } else {
                                state.currentTab = BrowserTab(originalQuery: "")
                                state.mode = .note
                            }
                            state.tabs.remove(at: i)
                            break
                        }
                    }
                }.opacity(showButton ? 1 : 0)
                .onHover(perform: { v in
                    showButton = v
                })
                .buttonStyle(BorderlessButtonStyle())
                .padding(.leading, 4)

            Text(tab.title)
            .padding(.top, 2)
            .padding([.trailing], 10)
            .frame(minWidth: 50, maxWidth: .infinity, minHeight: 20, maxHeight: 20, alignment: .leading)
            .font(selected ? .system(size: 12, weight: .bold) : .system(size: 12, weight: .regular))
        }
    }.frame(minWidth: 50, maxWidth: .infinity, minHeight: 20, maxHeight: 20, alignment: .leading)
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
}

struct BrowserTabView_Previews: PreviewProvider {
    static var tab = BrowserTab(originalQuery: "test tab1")
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
