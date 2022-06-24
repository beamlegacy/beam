import {
  BeamElement,
  BeamHTMLElement,
  BeamWindow,
  MessageHandlers
} from "@beam/native-beamtypes"
import {dequal as isDeepEqual} from "dequal"

export class BeamEmbedHelper {
  embedPattern = "__EMBEDPATTERN__"
  embedRegex: RegExp
  // Used when the embed iframe navigates after loading the first url
  firstLocationLoaded?: Location
  win: BeamWindow<MessageHandlers>

  constructor(win: BeamWindow) {
    this.win = win
    this.embedRegex = new RegExp(this.embedPattern, "i")
    this.firstLocationLoaded = this.win.location
  }

  /**
   * Returns true if element is Embed.
   *
   * @param {BeamElement} element
   * @param {BeamWindow} win
   * @return {*}  {boolean}
   * @memberof BeamEmbedHelper
   */
   isEmbeddableElement(element: any): boolean {
     const isInsideIframe = this.isOnFullEmbeddablePage()
     // Check if current window location is matching embed url and is inside an iframe context
     if (isInsideIframe) {
       return isInsideIframe
      }
      
    // check the element if it's embeddable
    switch (this.win.location.hostname) {
      case "twitter.com":
        return this.isTweet(element)
        break
      case "www.youtube.com":
        return (
          this.isYouTubeThumbnail(element) ||
          this.isEmbeddableIframe(element) ||
          this.win.location.pathname.includes("/embed/")
        )
        break
      default:
        return this.isEmbeddableIframe(element)
        break
    }
  }

  /**
   * Returns the window location or first loaded location that matches 
   * the embed or iframe regex
   *
   * @return {*}  {(string | undefined)}
   * @memberof BeamEmbedHelper
   */
  getEmbeddableWindowLocationLastUrls: string[]
  getEmbeddableWindowLocationLastResult: string
  getEmbeddableWindowLocation(): string | undefined {
    const urls = [ this.win.location.href, this.firstLocationLoaded.href ]
    if (isDeepEqual(urls, this.getEmbeddableWindowLocationLastUrls)) {
      return this.getEmbeddableWindowLocationLastResult
    }
    
    const result = urls.find(url => {
      return this.embedRegex.test(url)
    })
    
    this.getEmbeddableWindowLocationLastUrls = urls
    this.getEmbeddableWindowLocationLastResult = result

    return result
  }

  isOnFullEmbeddablePage() {
    return (
      (
        this.urlMatchesEmbedProvider([this.win.location.href, this.firstLocationLoaded.href])
      ) &&
      this.isInsideIframe()
    )
  }

  isEmbeddableIframe(element: BeamElement): boolean {
    if (["iframe"].includes(element.tagName.toLowerCase())) {
      return this.urlMatchesEmbedProvider([element.src])
    }
    return false
  }

  urlMatchesEmbedProviderLastUrls: string[]
  urlMatchesEmbedProviderLastResult: boolean
  urlMatchesEmbedProvider(urls: string[]): boolean {
    if (isDeepEqual(urls, this.urlMatchesEmbedProviderLastUrls)) {
      return this.urlMatchesEmbedProviderLastResult
    }
    const result = urls.some((url) => {
      if (!url) return false
      return this.embedRegex.test(url) || url.includes("youtube.com/embed")
    })

    this.urlMatchesEmbedProviderLastUrls = urls
    this.urlMatchesEmbedProviderLastResult = result

    return result
  }

  /**
   * Returns true if current window context is not the top level window context
   *
   * @return {*}  {boolean}
   * @memberof BeamEmbedHelper
   */
  isInsideIframe(): boolean {
    try {
      return window.self !== window.top
    } catch (e) {
      return true
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
        // see if we target the tweet html
        return this.parseTwitterElementForEmbed(element)
        break
      case "www.youtube.com":
        if (this.win.location.pathname.includes("/embed/")) {
          const videoId = window.location.pathname.split("/").pop()
          return this.createLinkElement(
            `https://www.youtube.com/watch?v=${videoId}`
          )
        }
        return this.parseYouTubeThumbnailForEmbed(element)
        break
      default:
        if (element.src && this.urlMatchesEmbedProvider([element.src])) {
          return this.createLinkElement(element.src)
        }
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
    const linkElements = element.querySelectorAll("a[href*=\"/status/\"]")
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
    const isThumb = Boolean(element?.href?.includes("/watch?v="))

    if (isThumb) {
      return true
    }

    const parentLinkElement = this.hasParentOfType(element, "A", 5)
    return Boolean(parentLinkElement?.href?.includes("/watch?v="))
  }

  /**
   * Returns parent of node type. Maximum allowed recursive depth is 10
   *
   * @static
   * @param {BeamElement} node target node to start at
   * @param {string} type parent type to search for
   * @param {number} [count=10] maximum depth of recursion, defaults to 10
   * @return {*}  {(BeamElement | undefined)}
   * @memberof BeamEmbedHelper
   */
  hasParentOfType(
    element: BeamElement,
    type: string,
    count = 10
  ): BeamElement | undefined {
    if (count <= 0) return null
    if (type !== "BODY" && element?.tagName === "BODY") return null
    if (!element?.parentElement) return null
    if (type === element?.tagName) return element
    const newCount = count--
    return this.hasParentOfType(element.parentElement, type, newCount)
  }

  /**
   * Parse html element into a Anchortag if it's a youtube thumbnail
   *
   * @param {BeamElement} element
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
    const parentLinkElement = this.hasParentOfType(element, "A", 5)
    if (parentLinkElement?.href?.includes("/watch?v=")) {
      return this.createLinkElement(parentLinkElement?.href)
    }

    return
  }

  /**
   * Return BeamHTMLElement of an Anchortag with provided href attribute
   *
   * @param {string} href
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
