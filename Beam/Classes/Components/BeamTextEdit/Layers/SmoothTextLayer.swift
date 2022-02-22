import QuartzCore

class SmoothTextLayer: CATextLayer {

    override func draw(in ctx: CGContext) {
        ctx.setShouldSmoothFonts(true)
        super.draw(in: ctx)
    }

}
