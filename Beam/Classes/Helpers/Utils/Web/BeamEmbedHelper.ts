import { BeamElementHelper } from "./BeamElementHelper";
import { BeamElement, BeamHTMLElement, BeamWindow, MessageHandlers } from "./BeamTypes"

export class BeamEmbedHelper {
  pattern = "__EMBEDPATTERN__"
  regex: RegExp 
  win: BeamWindow<MessageHandlers>

  constructor(win: BeamWindow) {
    this.win = win
    this.regex = new RegExp(this.pattern, "i")
  }

  /**
   * Returns true if element is Embed.
   * 
   * @param {BeamElement} element
   * @param {BeamWindow} win
   * @return {*}  {boolean}
   * @memberof BeamElementHelper
   */
   isEmbeddableElement(element: BeamElement): boolean {
     // Check if current window location is matching embed url and is inside an iframe context
     if (this.urlMatchesEmbedProvider([this.win.location.href])) {
       return this.isInsideIframe()
     }
     
    // check the element if it's embeddable
    switch (this.win.location.hostname) {
      case "twitter.com":
        return this.isTweet(element)
        break
      case "www.youtube.com":
        return this.isYouTubeThumbnail(element) || this.isEmbeddableIframe(element) || this.win.location.pathname.includes("/embed/")
        break
      default:
        return this.isEmbeddableIframe(element)
        break
    }
  }

  isOnFullEmbeddablePage() {
    return this.urlMatchesEmbedProvider([this.win.location.href])
  }

  isEmbeddableIframe(element: BeamElement): boolean {
    if (["iframe"].includes(element.tagName.toLowerCase())) {
      return this.urlMatchesEmbedProvider([element.src])
    }
    return false
  }

  urlMatchesEmbedProvider(urls: string[]): boolean {
    return urls.some(url => {
      if (!url) return false
      return this.regex.test(url) || url.includes("youtube.com/embed")
    })
  }

  isInsideIframe(): boolean {
    try {
      return window.self !== window.top;
    } catch (e) {
      return true;
    }
  }

  /**
   * Returns a url to the content to be inserted to the journal as embed.
   *
   * @param {BeamElement} element
   * @param {BeamWindow} win
   * @return {*}  {BeamHTMLElement}
   * @memberof this
   */
  parseElementForEmbed(element: BeamElement): BeamHTMLElement {
    const { hostname } = this.win.location

    switch (hostname) {
      case "twitter.com":
        return this.parseTwitterElementForEmbed(element)
        break
      case "www.youtube.com":
        if (this.win.location.pathname.includes("/embed/")) {
          let videoId = window.location.pathname.split("/").pop()
          return this.createLinkElement(`https://www.youtube.com/watch?v=${videoId}`);
        }
        return this.parseYouTubeThumbnailForEmbed(element)
        break
      default:
        return
        break
    }
  }
  /**
   * Convert element found on twitter.com to a anchor elemnt containing the tweet url. 
   * returns undefined when element isn't a tweet
   *
   * @param {BeamElement} element
   * @param {BeamWindow<any>} win
   * @return {*}  {BeamHTMLElement} 
   * @memberof this
   */
   parseTwitterElementForEmbed(element: BeamElement): BeamHTMLElement {
    if (!this.isTweet(element)) {
      return
    }

    // We are looking for a url like: <username>/status/1318584149247168513
    const linkElements = element.querySelectorAll('a[href*="/status/"]')
    // return the href of the first element in NodeList
    const href = linkElements?.[0].href
    
    if (href) {
      return this.createLinkElement(href)
    }
    
    return
  }
  /**
   * Returns if the provided element is a tweet. Should only be run on twitter.com
   *
   * @param {BeamElement} element
   * @return {*}  {boolean}
   * @memberof this
   */
  isTweet(element: BeamElement): boolean {
    return element.getAttribute("data-testid") == "tweet"
  }
  /**
   * Returns if the provided element is a YouTube Thumbnail. Should only be run on youtube.com
   *
   * @param {BeamElement} element
   * @return {*}  {boolean}
   * @memberof this
   */
   isYouTubeThumbnail(element: BeamElement): boolean {    
    let isThumb = Boolean(element?.href?.includes("/watch?v="))
    
    if (isThumb) {
      return true
    }

    let parentLinkElement = BeamElementHelper.hasParentOfType(element, "A", 5)
    return Boolean(parentLinkElement?.href?.includes("/watch?v="))
  }


  /**
   * Parse html element into a Anchortag if it's a youtube thumbnail
   *
   * @param {BeamElement} element
   * @param {BeamWindow<any>} win
   * @return {*}  {BeamHTMLElement}
   * @memberof this
   */
  parseYouTubeThumbnailForEmbed(element: BeamElement): BeamHTMLElement {
    if (!this.isYouTubeThumbnail(element)) {
      return
    }

    // We are looking for a url like: /watch?v=DtC8Trc2Fe0
    if (element?.href?.includes("/watch?v=")) {
      return this.createLinkElement(element?.href)
    }

    // Check parent link element
    let parentLinkElement = BeamElementHelper.hasParentOfType(element, "A", 5)
    if (parentLinkElement?.href?.includes("/watch?v=")) {
      return this.createLinkElement(parentLinkElement?.href)
    }

    return
  }

  /**
   * Return BeamHTMLElement of an Anchortag with provided href attribute
   *
   * @param {string} href
   * @param {BeamWindow} win
   * @return {*}  {BeamHTMLElement}
   * @memberof this
   */
  createLinkElement(href: string): BeamHTMLElement {
    const anchor = this.win.document.createElement("a")
    anchor.setAttribute("href", href)
    anchor.innerText = href
    return anchor
  }
}
