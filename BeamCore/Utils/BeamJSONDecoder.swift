//
//  BeamJSONDecoder
//  Beam
//
//  Created by Jérôme Blondon on 11/03/2022.
//

import Foundation
import ZippyJSON

/// Replacement for Swift JSONDecoder using ZippyJSON, which is a 4x+ faster.
///
/// Be aware that ZippyJSONDecoder might be very slow in debug configuration due to missing optimisations.
/// See https://github.com/michaeleisel/ZippyJSON/issues/21
public typealias BeamJSONDecoder = ZippyJSONDecoder
