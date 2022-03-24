import Foundation

/// A structure describing the geometric properties of some media content.
struct MediaContentGeometryDescription {

    let minWidth: CGFloat
    private(set) var idealWidth: CGFloat
    let maxWidth: CGFloat

    let minHeight: CGFloat
    private(set) var idealHeight: CGFloat
    let maxHeight: CGFloat

    let preservesAspectRatio: Bool
    let resizableAxes: ResponsiveType

    /// The content aspect ratio. Returns nil if the content has a free aspect ratio, or if it could not be computed.
    var aspectRatio: CGFloat? {
        guard
            preservesAspectRatio,
            idealWidth.isFinite,
            idealHeight.isFinite,
            idealHeight != .zero
        else {
            return nil
        }

        return idealHeight / idealWidth
    }

    var isHorizontallyResizable: Bool {
        resizableAxes == .horizontal || resizableAxes == .both
    }

    var isVerticallyResizable: Bool {
        resizableAxes == .vertical || resizableAxes == .both
    }

    init(
        minWidth: CGFloat? = nil,
        idealWidth: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        minHeight: CGFloat? = nil,
        idealHeight: CGFloat? = nil,
        maxHeight: CGFloat? = nil,
        preservesAspectRatio: Bool,
        resizableAxes: ResponsiveType = ResponsiveType.none
    ) {
        self.minWidth = minWidth ?? .zero
        self.idealWidth = idealWidth ?? .infinity
        self.maxWidth = maxWidth ?? .infinity

        self.minHeight = minHeight ?? .zero
        self.idealHeight = idealHeight ?? .infinity
        self.maxHeight = maxHeight ?? .infinity

        self.preservesAspectRatio = preservesAspectRatio
        self.resizableAxes = resizableAxes
    }

    /// Resizes the content horizontally if allowed.
    mutating func setPreferredWidth(_ width: CGFloat) {
        guard isHorizontallyResizable else { return }

        let aspectRatio = aspectRatio
        idealWidth = width

        if aspectRatio != nil {
            idealHeight = width * aspectRatio!
        }
    }

    /// Resizes the content vertically if allowed.
    mutating func setPreferredHeight(_ height: CGFloat) {
        guard isVerticallyResizable else { return }
        idealHeight = height
    }

    /// Overrides the display height, typically for media content whose geometry description does not provide a finite
    /// height. This is used for web view based content, when the actual height is only known after loading completes.
    mutating func setIdealHeight(_ height: CGFloat) {
        guard !preservesAspectRatio else { return }
        idealHeight = height
    }

}

extension MediaContentGeometryDescription {

    /// Returns a geometry description for an image node.
    static func image(sized size: CGSize) -> Self {
        MediaContentGeometryDescription(
            idealWidth: size.width,
            maxWidth: size.width,
            idealHeight: size.height,
            maxHeight: size.height,
            preservesAspectRatio: true,
            resizableAxes: .horizontal
        )
    }

    /// Returns a geometry description for an embed node.
    static func embed(_ content: EmbedContent) -> Self {
        MediaContentGeometryDescription(
            minWidth: content.minWidth,
            idealWidth: content.width,
            maxWidth: content.maxWidth,
            minHeight: content.minHeight,
            idealHeight: content.height,
            maxHeight: content.maxHeight,
            preservesAspectRatio: content.keepAspectRatio,
            resizableAxes: content.responsive ?? .none
        )
    }

}
