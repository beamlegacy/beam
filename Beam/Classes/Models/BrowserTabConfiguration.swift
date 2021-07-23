import Foundation

class BrowserTabConfiguration: BeamWebViewConfigurationBase {

    override func registerAllMessageHandlers() {
        LoggingMessageHandler(config: self).register(to: self)
        PasswordMessageHandler(config: self).register(to: self)
        ScorerMessageHandler(config: self).register(to: self)
        PointAndShootMessageHandler(config: self).register(to: self)
        WebNavigationMessageHandler(config: self).register(to: self)
        MediaPlayerMessageHandler(config: self).register(to: self)
        GeolocationMessageHandler(config: self).register(to: self)
    }

}
