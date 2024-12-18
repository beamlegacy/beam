//
//  BeamTableCellLottieView.swift
//  Beam
//
//  Created by Remi Santos on 14/03/2022.
//

import Foundation
import Lottie

class BeamTableCellLottieView: NSTableCellView {
    private let lottieView: LottieAnimationView
    private var animationName: String?

    override var wantsUpdateLayer: Bool { true }

    override init(frame frameRect: NSRect) {
        lottieView = LottieAnimationView()
        super.init(frame: frameRect)

        lottieView.loopMode = .loop
        lottieView.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(lottieView)
        self.addConstraints([
            centerXAnchor.constraint(equalTo: lottieView.centerXAnchor),
            centerYAnchor.constraint(equalTo: lottieView.centerYAnchor),
            lottieView.widthAnchor.constraint(equalToConstant: 16),
            lottieView.heightAnchor.constraint(equalToConstant: 16)
        ])
        self.textField?.isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateLayer() {
        if self.effectiveAppearance.isDarkMode {
            lottieView.layer?.compositingFilter = nil
        } else {
            lottieView.layer?.compositingFilter = "multiplyBlendMode"
        }
    }

    func updateWithLottie(named: String) {
        guard animationName != named else { return }
        let animation = LottieAnimation.named(named) // FIXME: we used a cache here? why the shared is not enough ?
        lottieView.animation = animation
        lottieView.setColor(BeamColor.LightStoneGray)
        lottieView.play()
    }
}
