import Foundation
import Lottie

extension AnimationView {

    func setColor(_ color: NSColor) {
        NSAppearance.withAppAppearance {
            let lottieColor = Lottie.Color(color: color)
            let colorProvider = ColorValueProvider(lottieColor)
            let fillKeypath = AnimationKeypath(keypath: "**.Color")
            setValueProvider(colorProvider, keypath: fillKeypath)
        }
    }

    func setColor(_ color: BeamColor) {
        setColor(color.nsColor)
    }

}
