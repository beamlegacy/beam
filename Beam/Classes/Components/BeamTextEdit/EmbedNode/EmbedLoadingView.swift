import AppKit

final class EmbedLoadingView: NSView {

    private var imageView: EmbedLoadingImageView!
    private var imageName: String?
    private let imageMinSize: CGFloat = 32

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

    override func layout() {
        super.layout()

        updateImage()
    }

    override func viewDidChangeEffectiveAppearance() {
        updateImage()
        updateColors()
    }

    func showImage(for provider: EmbedProvider) {
        setImage(name: ImageName.imageName(for: provider))
    }

    func showDefaultImage() {
        setImage(name: ImageName.default)
    }

    func showError() {
        setImage(name: ImageName.error)
    }

    private func prepare() {
        layer = CALayer()

        imageView = EmbedLoadingImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        let requiredConstraints = [
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),

            imageView.widthAnchor.constraint(greaterThanOrEqualToConstant: imageMinSize),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
            imageView.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor, multiplier: 1, constant: -16)
        ]

        let lowerPriorityContraints = [
            imageView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.14)
        ]

        lowerPriorityContraints.forEach { $0.priority = .defaultLow }

        addConstraints(requiredConstraints + lowerPriorityContraints)

        updateImage()
        updateColors()
    }

    private func setImage(name: String) {
        imageName = name
        updateImage()
    }

    private func updateImage() {
        guard
            let imageName = imageName,
            let image = NSImage(named: imageName)
        else {
            return
        }

        imageView.setImage(image)
    }

    private func updateColors() {
        layer?.backgroundColor = BeamColor.Nero.cgColor
    }

    // MARK: - ImageName

    private enum ImageName {

        static let `default` = "embed-logo_generic"
        static let error = "embed-logo_error"

        static func imageName(for provider: EmbedProvider) -> String {
            switch provider {
            case .unknown: return Self.default
            default: return "embed-logo_\(provider.rawValue.lowercased())"
            }
        }

    }

}
