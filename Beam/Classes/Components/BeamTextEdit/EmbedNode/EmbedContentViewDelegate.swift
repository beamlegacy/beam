import Foundation

protocol EmbedContentViewDelegate: AnyObject {

    func embedContentView(_ embedContentView: EmbedContentView, didReceiveEmbedContent embedContent: EmbedContent)
    func embedContentView(_ embedContentView: EmbedContentView, contentSizeDidChange size: CGSize)
    func embedContentView(_ embedContentView: EmbedContentView, didRequestNewTab url: URL)
    func embedContentView(_ embedContentView: EmbedContentView, didUpdateMediaPlayerController mediaPlayerController: MediaPlayerController?)

}
