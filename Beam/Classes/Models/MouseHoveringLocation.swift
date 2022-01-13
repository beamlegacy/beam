import Foundation

enum MouseHoveringLocation: Equatable {
    case none
    case link(url: URL, opensInNewTab: Bool)
}
