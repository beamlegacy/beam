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
   * @param {BeamHTMLElement} element
   * @param {BeamWindow} win
   * @return {*}  {string}
   * @memberof BeamEmbedHelper
   */
  static parseElementForEmbed(element: BeamHTMLElement, win: BeamWindow): string {
    const { hostname } = win.location

    switch (hostname) {
      case "twitter.com":
        return BeamEmbedHelper.parseTwitterElementForEmbed(element)
        break

      default:
        return
        break
    }
  }
  /**
   * convert element found on twitter.com to a tweet url. returns undefined when element isn't a tweet
   *
   * @static
   * @param {BeamHTMLElement} element
   * @return {*}  {string}
   * @memberof BeamEmbedHelper
   */
  static parseTwitterElementForEmbed(element: BeamHTMLElement): string {
    if (!BeamEmbedHelper.isTweet(element)) {
      return
    }

    // We are looking for a url like: <username>/status/1318584149247168513
    const linkElements = element.querySelectorAll('a[href*="/status/"]')
    // return the href of the first element in NodeList
    const href = linkElements?.[0].href
    return `<a href="${href}">${href}</a>`
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
}
