//
//  LottieView.swift
//  Beam
//
//  Created by Remi Santos on 20/09/2021.
//

import SwiftUI
import Lottie

extension Lottie.Color {
    init(color nscolor: NSColor) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        nscolor.usingColorSpace(.deviceRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(r: Double(r), g: Double(g), b: Double(b), a: Double(a))
    }
}

struct LottieView: NSViewRepresentable {
    var name = "editor-publish"
    var playing: Bool = false

    /// supports only single single for now
    var color: NSColor?

    var loopMode: LottieLoopMode = .loop
    var speed: CGFloat = 1

    var animationSize: CGSize?

    func makeNSView(context: NSViewRepresentableContext<LottieView>) -> AnimationContainerView {
        AnimationContainerView(animationSize: animationSize)
    }

    func updateNSView(_ animationContainerView: AnimationContainerView, context: NSViewRepresentableContext<LottieView>) {
        animationContainerView.animationName = name
        animationContainerView.color = color
        animationContainerView.isPlaying = playing
        animationContainerView.speed = speed
        animationContainerView.loopMode = loopMode
    }

    final class AnimationContainerView: NSView {

        var animationName: String? {
            didSet {
                guard
                    animationName != oldValue,
                    let animationName = animationName
                else {
                    return
                }

                animationView.animation = Animation.named(animationName)
            }
        }

        var color: NSColor? {
            didSet {
                guard
                    color != oldValue,
                    let color = color else {
                    return
                }

                animationView.setColor(color)
            }
        }

        var isPlaying = false {
            didSet {
                guard isPlaying != oldValue else { return }

                if isPlaying {
                    animationView.play()
                } else {
                    animationView.stop()
                }
            }
        }

        var speed: CGFloat = 1 {
            didSet {
                guard speed != oldValue else { return }
                animationView.animationSpeed = speed
            }
        }

        var loopMode: LottieLoopMode = .loop {
            didSet {
                guard loopMode != oldValue else { return }
                animationView.loopMode = loopMode
            }
        }

        private let animationView: AnimationView

        init(animationSize: CGSize?) {
            animationView = AnimationView()
            animationView.contentMode = .scaleAspectFit

            super.init(frame: .zero)

            addSubview(animationView)

            animationView.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                animationView.widthAnchor.constraint(equalTo: widthAnchor),
                animationView.heightAnchor.constraint(equalTo: heightAnchor)
            ])

            if let animationSize = animationSize {
                NSLayoutConstraint.activate([
                    widthAnchor.constraint(equalToConstant: animationSize.width),
                    heightAnchor.constraint(equalToConstant: animationSize.height)
                ])
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()

            if let color = color {
                animationView.setColor(color)
            }
        }

    }

}
