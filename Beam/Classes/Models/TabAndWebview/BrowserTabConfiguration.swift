import Foundation

class BrowserTabConfiguration: BeamWebViewConfigurationBase {

    override func registerAllMessageHandlers() {
        WebPositionsMessageHandler(config: self).register(to: self)
        if PreferencesManager.showPNSView == true {
            PointAndShootMessageHandler(config: self).register(to: self)
        }
        WebNavigationMessageHandler(config: self).register(to: self)
        LoggingMessageHandler(config: self).register(to: self)
        MediaPlayerMessageHandler(config: self).register(to: self)
        GeolocationMessageHandler(config: self).register(to: self)
        WebSearchMessageHandler(config: self).register(to: self)
        WebViewFocusMessageHandler(config: self).register(to: self)
        PasswordMessageHandler(config: self).register(to: self)
        LinkMouseOverMessageHandler(config: self).register(to: self)
    }

}
