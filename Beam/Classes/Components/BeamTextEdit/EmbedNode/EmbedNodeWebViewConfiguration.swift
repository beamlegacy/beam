//
//  EmbedNodeWebViewConfiguration.swift
//  Beam
//
//  Created by Stef Kors on 29/11/2021.
//

import Foundation

extension EmbedNode {
    class EmbedNodeWebViewConfiguration: BeamWebViewConfigurationBase {
        override func registerAllMessageHandlers() {
            LoggingMessageHandler(config: self).register(to: self)
            MediaPlayerMessageHandler(config: self).register(to: self)
            EmbedNodeMessageHandler(config: self).register(to: self)
        }
    }
}
