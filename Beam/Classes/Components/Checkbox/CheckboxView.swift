//
//  CheckboxView.swift
//  Beam
//
//  Created by Remi Santos on 29/09/2021.
//

import SwiftUI

struct CheckboxView: View {
    @Binding var checked: Bool
    var mixed: Bool = false

    @State var hovering = false
    @State var touchingDowm = false

    var body: some View {
        CheckboxerLayerView(checked: checked, hovering: hovering, clicked: touchingDowm, mixedState: mixed)
            .frame(width: 14, height: 14)
            .onHover { h in
                hovering = h
            }
            .onTouchDown { touchingDowm = $0 }
            .simultaneousGesture(TapGesture().onEnded {
                checked.toggle()
            })
    }
}

struct CheckboxerLayerView: NSViewRepresentable {
    var checked: Bool
    var hovering: Bool
    var clicked: Bool
    var mixedState: Bool

    func makeNSView(context: Context) -> some NSView {
        let view = NSView()
        view.wantsLayer = true
        let checkLayer = BeamCheckboxCALayer()
        view.layer?.addSublayer(checkLayer)
        return view
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {
        guard let layer = nsView.layer?.sublayers?.first(where: { $0 is BeamCheckboxCALayer }) as? BeamCheckboxCALayer else { return }
        layer.frame.origin = .zero
        layer.isHovering = hovering
        layer.isMouseDown = clicked
        layer.isMixedState = mixedState
        layer.isChecked = checked
    }
}

struct CheckboxView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HStack {
                VStack {
                    Text("Default")
                    CheckboxView(checked: .constant(false))
                    CheckboxView(checked: .constant(true))
                    CheckboxView(checked: .constant(false), mixed: true)
                }
                VStack {
                    Text("Hovering")
                    CheckboxView(checked: .constant(false), hovering: true)
                    CheckboxView(checked: .constant(true), hovering: true)
                    CheckboxView(checked: .constant(false), mixed: true, hovering: true)
                }
                VStack {
                    Text("Touching")
                    CheckboxView(checked: .constant(false), touchingDowm: true)
                    CheckboxView(checked: .constant(true), touchingDowm: true)
                    CheckboxView(checked: .constant(false), mixed: true, touchingDowm: true)
                }
            }
            .padding()
        }
    }
}
