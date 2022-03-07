import AppKit

final class EmbedLoadingView: NSView {

    init() {
        super.init(frame: .zero)
        prepare()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        prepare()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        updateColors()
    }

    private func prepare() {
        layer = CALayer()

        let attributedString = NSAttributedString(string: "Loading...", attributes: [
            .font: BeamFont.regular(size: 13).nsFont,
            .foregroundColor: BeamColor.AlphaGray.nsColor
        ])

        let text = NSTextField(labelWithAttributedString: attributedString)
        text.translatesAutoresizingMaskIntoConstraints = false

        addSubview(text)

        addConstraints([
            text.centerXAnchor.constraint(equalTo: centerXAnchor),
            text.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        updateColors()
    }

    private func updateColors() {
        layer?.backgroundColor = BeamColor.Nero.cgColor
    }

}
