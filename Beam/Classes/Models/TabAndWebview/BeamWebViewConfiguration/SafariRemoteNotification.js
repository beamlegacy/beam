// Mock implementation of the Safari Push Notification API
// https://developer.apple.com/documentation/safariextensions/safariremotenotification
// 
// Some sites will fail to detect Beam is like Safari based on the useragent alone. 
// Instead the SafariRemoteNotification API is widely used as an indicator.
// https://sourcegraph.com/search?q=context:global+SafariRemoteNotification&patternType=literal
// 
// Fixes: https://linear.app/beamapp/issue/BE-4166/not-able-to-see-canal-play-live-video
//
window.safari = {
  pushNotification: {
    requestPermission: () => {
      console.error("SafariRemoteNotification API is not supported in Beam")
    },
    permission: "default",
    toString: () => {
      return "[object SafariRemoteNotification]"
    }
  }
}
