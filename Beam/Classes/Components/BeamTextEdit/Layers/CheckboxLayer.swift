//
//  CheckboxLayer.swift
//  Beam
//
//  Created by Remi Santos on 22/06/2021.
//

import Foundation

class CheckboxLayer: Layer {
    private var onChange: ((Bool) -> Void)?
    private var squareLayer: CAShapeLayer?
    private var checkLayer: CALayer?
    private var extraStrokeLayer: CAShapeLayer?
    private var isMouseDown = false
    var isChecked = false {
        didSet {
            updateLayers()
        }
    }

    init(name: String, onChange: ((Bool) -> Void)?) {
        self.onChange = onChange
        super.init(name: name, layer: CALayer())
        self.layer.bounds = CGRect(x: 0, y: 0, width: 14, height: 14)
        setupLayers()
        cursor = .arrow
        mouseUp = { [unowned self] info -> Bool in
            guard layer.contains(info.position) else { return true }
            isMouseDown = false
            self.handleCheckChange()
            return true
        }

        mouseDown = { [unowned self] _ -> Bool in
            isMouseDown = true
            updateLayers()
            return true
        }
    }

    private func handleCheckChange() {
        isChecked = !isChecked
        self.onChange?(isChecked)
    }

    override func handleHover(_ value: Bool) {
        super.handleHover(value)
        if !value {
            isMouseDown = false
        }
        updateLayers()
    }

    private func setupLayers() {
        let baseRect = self.layer.bounds

        let square = CAShapeLayer()
        square.path = NSBezierPath(roundedRect: baseRect.insetBy(dx: 0.75, dy: 0.75), xRadius: 3, yRadius: 3).cgPath
        square.lineWidth = 1.5
        squareLayer = square
        self.layer.addSublayer(square)

        let stroke = CAShapeLayer()
        stroke.path = NSBezierPath(roundedRect: baseRect.insetBy(dx: 0.25, dy: 0.25), xRadius: 3, yRadius: 3).cgPath
        stroke.lineWidth = 0.5
        stroke.fillColor = .clear
        extraStrokeLayer = stroke
        self.layer.addSublayer(stroke)

        let iconLayer = Layer.icon(named: "checkbox-mark", color: BeamColor.Corduroy.nsColor, size: CGSize(width: 10, height: 10))
        let edge = (baseRect.width - 10) / 2
        iconLayer.frame.origin = CGPoint(x: edge, y: edge)
        checkLayer = iconLayer
        self.layer.addSublayer(iconLayer)

        updateLayers()
    }

    private func updateLayers() {
        checkLayer?.isHidden = !isChecked
        var fillColor = isChecked ? BeamColor.Mercury.cgColor : BeamColor.Generic.background.cgColor
        var strokeColor = BeamColor.Mercury.cgColor
        var extraStrokeColor = BeamColor.Niobium.nsColor.withAlphaComponent(0.05).cgColor
        var iconColor = BeamColor.Corduroy.cgColor
        if isMouseDown {
            fillColor = BeamColor.AlphaGray.cgColor
            strokeColor = BeamColor.AlphaGray.cgColor
            extraStrokeColor = BeamColor.Niobium.nsColor.withAlphaComponent(0.03).cgColor
            iconColor = BeamColor.Niobium.cgColor
        } else if hovering && !isChecked {
            strokeColor = BeamColor.AlphaGray.cgColor
        } else if hovering && isChecked {
            iconColor = BeamColor.Niobium.cgColor
        }

        squareLayer?.fillColor = fillColor
        squareLayer?.strokeColor = strokeColor
        extraStrokeLayer?.strokeColor = extraStrokeColor
        checkLayer?.backgroundColor = iconColor
    }
}
