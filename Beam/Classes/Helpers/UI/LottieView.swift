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

    public func makeCoordinator() -> Coordinator {
        return Coordinator()
    }

    func makeNSView(context: NSViewRepresentableContext<LottieView>) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.animationName = name
        let animationView = AnimationView()
        let animation = Animation.named(name)
        animationView.animation = animation
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = loopMode
        animationView.animationSpeed = speed

        if playing {
            animationView.play()
        }
        if let color = color {
            setColorForAllAnimationView(animationView: animationView, color: color)
            context.coordinator.color = color
        }
        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor),
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])

        if let animationSize = animationSize {
            NSLayoutConstraint.activate([
                view.heightAnchor.constraint(equalToConstant: animationSize.height),
                view.widthAnchor.constraint(equalToConstant: animationSize.width)
            ])
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: NSViewRepresentableContext<LottieView>) {
        guard let animationView = nsView.subviews.first(where: { $0 is AnimationView }) as? AnimationView
        else { return }
        if name != context.coordinator.animationName {
            let animation = Animation.named(name)
            animationView.animation = animation
            context.coordinator.animationName = name
        }
        if let color = color, color != context.coordinator.color {
            setColorForAllAnimationView(animationView: animationView, color: color)
            context.coordinator.color = color
        }
        if playing && !animationView.isAnimationPlaying {
            animationView.play()
        } else if !playing && animationView.isAnimationPlaying {
            animationView.stop()
        }
        animationView.animationSpeed = speed
    }

    private func setColorForAllAnimationView(animationView: AnimationView, color: NSColor) {

        let colorProvider = ColorValueProvider(Lottie.Color(color: color))
        animationView.setValueProvider(colorProvider, keypath: AnimationKeypath(keypath: "**.Color"))
    }

    class Coordinator: NSObject {
        var animationName: String?
        var color: NSColor?
        override init() {
            super.init()
        }
    }
}
