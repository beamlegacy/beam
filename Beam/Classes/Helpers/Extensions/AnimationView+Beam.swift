import Foundation
import Lottie

extension LottieAnimationView {

    func setColor(_ color: NSColor) {
        NSAppearance.withAppAppearance {
            let lottieColor = LottieColor(color: color)
            let colorProvider = ColorValueProvider(lottieColor)
            let fillKeypath = AnimationKeypath(keypath: "**.Color")
            setValueProvider(colorProvider, keypath: fillKeypath)
        }
    }

    func setColor(_ color: BeamColor) {
        setColor(color.nsColor)
    }

}
