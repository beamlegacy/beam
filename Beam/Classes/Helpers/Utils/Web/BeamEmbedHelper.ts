import { BeamElementHelper } from "./BeamElementHelper";
import { BeamElement, BeamHTMLElement, BeamWindow } from "./BeamTypes"

export class BeamEmbedHelper {
  /**
   * Returns true if element is Embed. Currently supports the following services:
   * - Twitter
   *
   * @static
   * @param {BeamElement} element
   * @param {BeamWindow} win
   * @return {*}  {boolean}
   * @memberof BeamElementHelper
   */
  static isEmbed(element: BeamElement, win: BeamWindow): boolean {
    switch (win.location.hostname) {
      case "twitter.com":
        return BeamEmbedHelper.isTweet(element)
        break
      case "www.youtube.com":
        return BeamEmbedHelper.isYouTubeThumbnail(element)
        break
      default:
        return false
        break
    }
  }

  /**
   * Returns a url to the content to be inserted to the journal as embed. Currently supports the following services:
   * - Twitter
   *
   * @static
   * @param {BeamElement} element
   * @param {BeamWindow} win
   * @return {*}  {BeamHTMLElement}
   * @memberof BeamEmbedHelper
   */
  static parseElementForEmbed(element: BeamElement, win: BeamWindow): BeamHTMLElement {
    const { hostname } = win.location

    switch (hostname) {
      case "twitter.com":
        return BeamEmbedHelper.parseTwitterElementForEmbed(element, win)
        break
      case "www.youtube.com":
        return BeamEmbedHelper.parseYouTubeThumbnailForEmbed(element, win)
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
   * @static
   * @param {BeamElement} element
   * @param {BeamWindow<any>} win
   * @return {*}  {BeamHTMLElement} 
   * @memberof BeamEmbedHelper
   */
  static parseTwitterElementForEmbed(element: BeamElement, win: BeamWindow<any>): BeamHTMLElement {
    if (!BeamEmbedHelper.isTweet(element)) {
      return
    }

    // We are looking for a url like: <username>/status/1318584149247168513
    const linkElements = element.querySelectorAll('a[href*="/status/"]')
    // return the href of the first element in NodeList
    const href = linkElements?.[0].href
    
    if (href) {
      return BeamEmbedHelper.createLinkElement(href, win)
    }
    
    return
  }
  /**
   * Returns if the provided element is a tweet. Should only be run on twitter.com
   *
   * @static
   * @param {BeamElement} element
   * @return {*}  {boolean}
   * @memberof BeamEmbedHelper
   */
  static isTweet(element: BeamElement): boolean {
    return element.getAttribute("data-testid") == "tweet"
  }
  /**
   * Returns if the provided element is a YouTube Thumbnail. Should only be run on youtube.com
   *
   * @static
   * @param {BeamElement} element
   * @return {*}  {boolean}
   * @memberof BeamEmbedHelper
   */
  static isYouTubeThumbnail(element: BeamElement): boolean {    
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
   * @static
   * @param {BeamElement} element
   * @param {BeamWindow<any>} win
   * @return {*}  {BeamHTMLElement}
   * @memberof BeamEmbedHelper
   */
  static parseYouTubeThumbnailForEmbed(element: BeamElement, win: BeamWindow<any>): BeamHTMLElement {
    if (!BeamEmbedHelper.isYouTubeThumbnail(element)) {
      return
    }

    // We are looking for a url like: /watch?v=DtC8Trc2Fe0
    if (element?.href?.includes("/watch?v=")) {
      return BeamEmbedHelper.createLinkElement(element?.href, win)
    }

    // Check parent link element
    let parentLinkElement = BeamElementHelper.hasParentOfType(element, "A", 5)
    if (parentLinkElement?.href?.includes("/watch?v=")) {
      return BeamEmbedHelper.createLinkElement(parentLinkElement?.href, win)
    }

    return
  }

  /**
   * Return BeamHTMLElement of an Anchortag with provided href attribute
   *
   * @static
   * @param {string} href
   * @param {BeamWindow} win
   * @return {*}  {BeamHTMLElement}
   * @memberof BeamEmbedHelper
   */
  static createLinkElement(href: string, win: BeamWindow): BeamHTMLElement {
    const anchor = win.document.createElement("a")
    anchor.setAttribute("href", href)
    anchor.innerText = href
    return anchor
  }
}
