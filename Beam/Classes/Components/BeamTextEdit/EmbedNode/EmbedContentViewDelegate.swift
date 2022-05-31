import Foundation

protocol EmbedContentViewDelegate: AnyObject {

    func embedContentViewDidBecomeReady(_ embedContentView: EmbedContentView)
    func embedContentView(_ embedContentView: EmbedContentView, contentSizeDidChange size: CGSize)
    func embedContentView(_ embedContentView: EmbedContentView, didRequestNewTab request: URLRequest?)
    func embedContentView(_ embedContentView: EmbedContentView, didUpdateMediaPlayerController mediaPlayerController: MediaPlayerController?)

}
