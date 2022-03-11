//
//  CGSize+Beam.swift
//  Beam
//
//  Created by Stef Kors on 14/12/2021.
//

import Foundation
import Sentry

extension CGSize {
    var aspectRatio: CGFloat {
        let dividingBy0 = self.width == 0.0

        //Asserting to have rapid fix from devs and guarding with fixed value to not break the users, and warn through Sentry
        assert(!dividingBy0)
        guard !dividingBy0 else {
            SentrySDK.capture(message: "[Dividing by 0] Trying to compute a aspectRatio for a CGSize with a size width to 0")
            return 1.0
        }
        return self.height / self.width
    }
}
