import Foundation

final class EmbedNodeWebViewConfiguration: BeamWebViewConfigurationBase {

    override func registerAllMessageHandlers() {
        LoggingMessageHandler(config: self).register(to: self)
        MediaPlayerMessageHandler(config: self).register(to: self)
        EmbedNodeMessageHandler(config: self).register(to: self)
    }

}
