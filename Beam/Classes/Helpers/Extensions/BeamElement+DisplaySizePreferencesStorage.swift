import BeamCore

extension BeamElement: MediaContentDisplaySizePreferencesStorage {

    var displaySizePreferences: MediaContentGeometry.DisplaySizePreferences? {
        get {
            switch kind {
            case let .image(_, _, displayInfos):
                guard
                    let width = displayInfos.width,
                    let height = displayInfos.height,
                    let ratio = displayInfos.displayRatio else {
                        return nil
                    }

                return .contentSize(
                    containerWidthRatio: ratio,
                    contentWidth: CGFloat(width),
                    contentHeight: CGFloat(height)
                )

            case let .embed(_, origin: _, displayInfos: displayInfos):
                guard let ratio = displayInfos.displayRatio else { return nil }

                let displayHeight: CGFloat?
                if displayInfos.height != nil {
                    displayHeight = CGFloat(displayInfos.height!)
                } else {
                    displayHeight = nil
                }

                return .displayHeight(
                    containerWidthRatio: ratio,
                    displayHeight: displayHeight
                )

            default: return nil
            }
        }

        set {
            switch (kind, newValue) {
            case let (
                .image(uuid, origin: origin, displayInfos: _),
                .contentSize(containerWidthRatio: ratio, contentWidth: width, contentHeight: height)
            ):
                let displayInfos = MediaDisplayInfos(
                    height: Int(height),
                    width: Int(width),
                    displayRatio: ratio
                )

                kind = .image(uuid, origin: origin, displayInfos: displayInfos)

            case let (
                .embed(url, origin: origin, displayInfos: _),
                .displayHeight(containerWidthRatio: ratio, displayHeight: displayHeight)
            ):
                let height: Int?
                if displayHeight != nil {
                    height = Int(displayHeight!)
                } else {
                    height = nil
                }

                let displayInfos = MediaDisplayInfos(
                    height: height,
                    width: nil,
                    displayRatio: ratio
                )

                kind = .embed(url, origin: origin, displayInfos: displayInfos)

            default: break
            }
        }
    }

}
