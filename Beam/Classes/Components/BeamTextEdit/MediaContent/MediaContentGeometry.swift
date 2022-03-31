import Foundation
import Combine

/// A structure computing the display size of some media content.
///
/// The display size is computed from:
/// - The viewport properties.
/// - The content geometry properties (minimum, ideal, maximum sizes, the resizable axes, etc.)
/// - An optional display size preference if the content has been resized.
/// - An optional display size override if the media content needs more display area.
/// - A fallback display size stored in cache, used while the content geometry properties are still undefined.
struct MediaContentGeometry {

    var displaySize: CGSize {
        var description: MediaContentGeometryDescription

        if let lockedGeometryDescription = lockedGeometryDescription {
            // Use cached display size
            description = lockedGeometryDescription

        } else {
            description = geometryDescription

            // Apply overrides
            if let preferredDisplayWidth = preferredDisplayWidth {
                description.setPreferredWidth(preferredDisplayWidth)
            }

            if let preferredDisplayHeight = preferredDisplayHeight {
                description.setPreferredHeight(preferredDisplayHeight)

            } else if let heightOverride = displaySizeOverride?.height {
                description.setIdealHeight(heightOverride)
            }
        }

        var width = description.idealWidth
        var height = description.idealHeight
        var aspectRatio: CGFloat?

        // Apply content and viewport boundaries to display width
        width = width.clamp(
            max(
                description.minWidth,
                Self.defaultDisplayMinSize.width
            ),
            min(
                description.maxWidth,
                containerWidth,
                Self.defaultDisplayMaxSize.width
            )
        )

        if let ratio = description.aspectRatio {
            aspectRatio = ratio

        } else if !height.isFinite {
            // Fallback on default aspect ratio
            aspectRatio = Self.defaultAspectRatio
        }

        // Apply aspect ratio
        if let aspectRatio = aspectRatio {
            height = width * aspectRatio
        }

        // Apply content and viewport boundaries to display height
        height = height.clamp(
            max(
                description.minHeight,
                Self.defaultDisplayMinSize.height
            ),
            min(
                description.maxHeight,
                Self.defaultDisplayMaxSize.height
            )
        )

        if let aspectRatio = aspectRatio {
            // Apply aspect ratio again in case the display height was clamped.
            width = height / aspectRatio
        }

        let displaySize = CGSize(width: width, height: height)
        displaySizeCache?.displaySize = displaySize
        return displaySize
    }

    /// Whether the display size is locked onto its last known value, until it's unlocked.
    var isLocked: Bool {
        get {
            lockedGeometryDescription != nil
        }

        set {
            if newValue, lockedGeometryDescription == nil {
                let displaySize = displaySizeCache?.displaySize ?? displaySize
                lockedGeometryDescription = MediaContentGeometryDescription(
                    idealWidth: displaySize.width,
                    idealHeight: displaySize.height,
                    preservesAspectRatio: geometryDescription.preservesAspectRatio,
                    resizableAxes: geometryDescription.resizableAxes
                )

            } else {
                lockedGeometryDescription = nil
            }
        }
    }

    var resizableAxes: ResponsiveType {
        geometryDescription.resizableAxes
    }

    /// The viewport's width.
    private var containerWidth: CGFloat = Self.defaultContainerWidth

    /// The media content geometry properties describing its minimum, ideal, and maximum size, on which axes it can
    /// be resized, and whether its aspect ratio is preserved.
    private var geometryDescription = Self.defaultGeometryDescription

    private var preferredDisplayWidth: CGFloat? {
        switch preferredDisplayWidthDimension {
        case let .absolute(width): return width
        case let .containerRatio(ratio): return ratio * containerWidth
        default: return nil
        }
    }

    /// The preferred display width when the media content has been horizontally resized.
    private var preferredDisplayWidthDimension: DisplayDimension?

    /// The preferred display height when the media content has been vertically resized.
    private var preferredDisplayHeight: CGFloat?

    /// An object to persist the size preferences into, when the media content has been resized.
    private var sizePreferencesStorage: MediaContentDisplaySizePreferencesStorage?

    /// Describes which geometry properties are persisted when the media content has been resized.
    private let sizePreferencesPersistenceStrategy: SizePreferencesPersistenceStrategy?

    /// An object providing a fallback display size, used while the content geometry properties are still undefined.
    private var displaySizeCache: MediaContentDisplaySizeCache?

    /// A value overriding the display size, typically for media content whose geometry description does not provide a
    /// finite height. This is used for web view based content, when the actual height is only known after loading
    /// completes. Only the display height can be overriden.
    private var displaySizeOverride: CGSize?

    /// The last known geometry description when the content geometry was locked.
    private var lockedGeometryDescription: MediaContentGeometryDescription?

    init(
        sizePreferencesStorage: MediaContentDisplaySizePreferencesStorage? = nil,
        sizePreferencesPersistenceStrategy: SizePreferencesPersistenceStrategy? = nil,
        displaySizeCache: MediaContentDisplaySizeCache? = nil
    ) {
        self.sizePreferencesStorage = sizePreferencesStorage
        self.sizePreferencesPersistenceStrategy = sizePreferencesPersistenceStrategy
        self.displaySizeCache = displaySizeCache

        if let cachedDisplaySize = displaySizeCache?.displaySize {
            // Retrieve display data from display size cache
            geometryDescription = MediaContentGeometryDescription(
                idealWidth: cachedDisplaySize.width,
                idealHeight: cachedDisplaySize.height,
                preservesAspectRatio: true
            )

        } else if let displaySizePreferences = sizePreferencesStorage?.displaySizePreferences {
            // Retrieve display data from size preferences storage
            switch displaySizePreferences {
            case let .contentSize(_, contentWidth, contentHeight):
                geometryDescription = MediaContentGeometryDescription(
                    idealWidth: contentWidth,
                    maxWidth: contentWidth,
                    idealHeight: contentHeight,
                    maxHeight: contentHeight,
                    preservesAspectRatio: true,
                    resizableAxes: .horizontal
                )

            case let .displayHeight(_, displayHeight):
                geometryDescription = MediaContentGeometryDescription(
                    preservesAspectRatio: false,
                    resizableAxes: (displayHeight == nil) ? .horizontal : .both
                )
            }
        }

        applyDisplaySizePreferences()
    }

    mutating func setContainerWidth(_ width: CGFloat) {
        containerWidth = width
    }

    mutating func setGeometryDescription(_ description: MediaContentGeometryDescription) {
        geometryDescription = description
    }

    mutating func setPreferredDisplayWidth(_ width: CGFloat) {
        preferredDisplayWidthDimension = .absolute(width)
    }

    mutating func setPreferredDisplayHeight(_ height: CGFloat) {
        preferredDisplayHeight = height
    }

    /// Persists the display size preferences.
    mutating func savePreferredDisplaySize() {
        let containerWidthRatio: CGFloat

        if let preferredWidth = preferredDisplayWidth {
            let minWidth = max(geometryDescription.minWidth, Self.defaultDisplayMinSize.width)
            let maxWidth = min(geometryDescription.maxWidth, Self.defaultDisplayMaxSize.width)
            let clampedPreferredWidth = preferredWidth.clamp(minWidth, maxWidth)
            containerWidthRatio = (clampedPreferredWidth / containerWidth).clamp(0, 1)
        } else {
            containerWidthRatio = 1
        }

        switch sizePreferencesPersistenceStrategy {
        case .contentSize:
            guard
                geometryDescription.idealWidth.isFinite,
                geometryDescription.idealHeight.isFinite
            else {
                break
            }

            sizePreferencesStorage?.displaySizePreferences = .contentSize(
                containerWidthRatio: containerWidthRatio,
                contentWidth: geometryDescription.idealWidth,
                contentHeight: geometryDescription.idealHeight
            )

        case .displayHeight:
            var displayHeight: CGFloat?

            if geometryDescription.isVerticallyResizable,
               let preferredDisplayHeight = preferredDisplayHeight {
                let minHeight = max(geometryDescription.minHeight, Self.defaultDisplayMinSize.height)
                let maxHeight = min(geometryDescription.maxHeight, Self.defaultDisplayMaxSize.height)

                let clampedHeight = preferredDisplayHeight.clamp(minHeight, maxHeight)
                displayHeight = clampedHeight
            }

            sizePreferencesStorage?.displaySizePreferences = .displayHeight(
                containerWidthRatio: containerWidthRatio,
                displayHeight: displayHeight
            )

        default: break
        }
    }

    /// Overrides the display size, typically for media content whose geometry description does not provide a finite
    /// height. This is used for web view based content, when the actual height is only known after loading completes.
    /// Only the display height can be overriden.
    mutating func setDisplaySizeOverride(_ size: CGSize) {
        guard
            !geometryDescription.preservesAspectRatio,
            !geometryDescription.isVerticallyResizable else {
            return
        }

        displaySizeOverride = size
    }

    /// Applies the display size preferences from the size preferences storage. Call this method in order to update
    /// the display size whenever the display size preferences have changed.
    mutating func applyDisplaySizePreferences() {
        if let ratio = sizePreferencesStorage?.displaySizePreferences?.containerWidthRatio {
            preferredDisplayWidthDimension = .containerRatio(ratio)
        }

        preferredDisplayHeight = sizePreferencesStorage?.displaySizePreferences?.displayHeight
    }

    // MARK: - Viewport defaults

    /// The initial display size when no other geometry information is available.
    private static let defaultGeometryDescription = MediaContentGeometryDescription(
        idealWidth: 170,
        idealHeight: 128,
        preservesAspectRatio: true
    )

    private static let defaultAspectRatio: Double = 3 / 4
    private static let defaultDisplayMinSize = CGSize(width: 48, height: 48)
    private static let defaultDisplayMaxSize = CGSize(width: CGFloat.infinity, height: 2200)
    private static let defaultContainerWidth: CGFloat = 300

    // MARK: - DisplayDimension

    /// A value describing the calculation of the dimension of the media content.
    enum DisplayDimension {

        /// A value set in points.
        case absolute(CGFloat)

        /// A value set as a ratio of the containing viewport's dimension.
        case containerRatio(CGFloat)

    }

    // MARK: - DisplaySizePreferences

    /// A value describing how the media content has been resized.
    /// In every case, the display width is calculated as a ratio of the viewport.
    enum DisplaySizePreferences: Equatable {

        /// Stores the width ratio and the actual content width.
        case contentSize(containerWidthRatio: CGFloat, contentWidth: CGFloat, contentHeight: CGFloat)

        /// Stores the width ratio and the resized display height.
        case displayHeight(containerWidthRatio: CGFloat, displayHeight: CGFloat?)

        var containerWidthRatio: CGFloat {
            switch self {
            case let .contentSize(ratio, _, _): return ratio
            case let .displayHeight(ratio, _): return ratio
            }
        }

        var displayHeight: CGFloat? {
            switch self {
            case let .displayHeight(_, height): return height
            default: return nil
            }
        }

    }

    // MARK: - SizePreferencesPersistenceStrategy

    /// A value describing which geometry properties are persisted when the media content has been resized.
    enum SizePreferencesPersistenceStrategy {

        /// Stores the width ratio and the actual content width.
        case contentSize

        /// Stores the width ratio and the user-set display height.
        case displayHeight

    }

}

// MARK: - MediaContentDisplaySizePreferencesStorage

protocol MediaContentDisplaySizePreferencesStorage {
    var displaySizePreferences: MediaContentGeometry.DisplaySizePreferences? { get set }
}

// MARK: - MediaContentDisplaySizeCache

protocol MediaContentDisplaySizeCache: AnyObject {
    var displaySize: CGSize? { get set }
}
