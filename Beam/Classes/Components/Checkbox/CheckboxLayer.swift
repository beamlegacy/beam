//
//  CheckboxLayer.swift
//  Beam
//
//  Created by Remi Santos on 22/06/2021.
//

import Foundation

class CheckboxLayer: Layer {
    private var onChange: ((Bool) -> Void)?
    private var checkbox: BeamCheckboxCALayer
    private var isMouseDown = false
    var isChecked = false {
        didSet {
            updateLayers()
        }
    }

    init(name: String, onChange: ((Bool) -> Void)?) {
        self.onChange = onChange
        self.checkbox = BeamCheckboxCALayer()
        super.init(name: name, layer: self.checkbox)
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

    private func updateLayers() {
        checkbox.isChecked = isChecked
        checkbox.isHovering = hovering
        checkbox.isMouseDown = isMouseDown
    }
}

class BeamCheckboxCALayer: CALayer {
    private var squareLayer: CAShapeLayer?
    private var checkLayer: CALayer?
    private var mixedLayer: CAShapeLayer?
    private var innerStrokeLayer: CAShapeLayer?
    var isMouseDown = false
    var isHovering = false
    var isChecked = false {
        didSet {
            updateLayers()
        }
    }
    var isMixedState = false {
        didSet {
            updateLayers()
        }
    }

    override init() {
        super.init()
        bounds = CGRect(x: 0, y: 0, width: 14, height: 14)
        setupLayers()
    }

    override init(layer: Any) {
        if let layer = layer as? BeamCheckboxCALayer {
            squareLayer = layer.squareLayer
            checkLayer = layer.checkLayer
            mixedLayer = layer.mixedLayer
            innerStrokeLayer = layer.innerStrokeLayer
        }
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayers() {
        let baseRect = self.bounds

        let square = CAShapeLayer()
        square.path = NSBezierPath(roundedRect: baseRect, xRadius: 3, yRadius: 3).cgPath
        squareLayer = square
        self.addSublayer(square)

        let stroke = CAShapeLayer()
        stroke.path = NSBezierPath(roundedRect: baseRect.insetBy(dx: 0.25, dy: 0.25), xRadius: 3, yRadius: 3).cgPath
        stroke.lineWidth = 0.5
        stroke.fillColor = .clear
        innerStrokeLayer = stroke
        self.addSublayer(stroke)

        let iconLayer = Layer.icon(named: "checkbox-mark", color: BeamColor.Niobium.nsColor, size: CGSize(width: 10, height: 10))
        let edge = (baseRect.width - 10) / 2
        iconLayer.frame.origin = CGPoint(x: edge, y: edge)
        checkLayer = iconLayer
        self.addSublayer(iconLayer)

        let mixedLayer = CAShapeLayer()
        mixedLayer.path = NSBezierPath(roundedRect: CGRect(x: 4, y: 6, width: 6, height: 2), xRadius: 1, yRadius: 1).cgPath
        mixedLayer.fillColor = BeamColor.Niobium.cgColor
        self.mixedLayer = mixedLayer
        self.addSublayer(mixedLayer)

        updateLayers()
    }

    override func layoutSublayers() {
        super.layoutSublayers()
        updateLayers()
    }

    private func updateLayers() {
        NSAppearance.withAppAppearance {
            checkLayer?.isHidden = !isChecked
            mixedLayer?.isHidden = isChecked || !isMixedState
            let hasContent = isChecked || isMixedState
            var fillColor = hasContent ? BeamColor.Mercury.cgColor : BeamColor.Nero.cgColor
            var innerStrokeColor = BeamColor.AlphaGray.cgColor
            if isMouseDown {
                fillColor = BeamColor.AlphaGray.cgColor
                innerStrokeColor = BeamColor.LightStoneGray.cgColor
            } else if isHovering {
                fillColor = hasContent ? BeamColor.Mercury.nsColor.add(BeamColor.Niobium.nsColor.withAlphaComponent(0.07)).cgColor : BeamColor.Mercury.cgColor
            }

            squareLayer?.fillColor = fillColor
            innerStrokeLayer?.strokeColor = innerStrokeColor
            mixedLayer?.fillColor = BeamColor.Niobium.cgColor
            checkLayer?.backgroundColor = BeamColor.Niobium.cgColor
        }
    }
}
