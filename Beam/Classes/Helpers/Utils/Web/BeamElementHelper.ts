import {
  BeamElement,
  BeamHTMLElement,
  BeamHTMLInputElement,
  BeamHTMLTextAreaElement,
  BeamRect,
  BeamWindow
} from "./BeamTypes"
import {BeamRectHelper} from "./BeamRectHelper"
import { BeamEmbedHelper } from "./BeamEmbedHelper"

/**
 * Useful methods for HTML Elements
 */
export class BeamElementHelper {
  static getAttribute(attr: string, element: BeamElement): string {
    const attribute = element.attributes.getNamedItem(attr)
    return attribute?.value
  }

  static getType(element: BeamElement): string {
    return BeamElementHelper.getAttribute("type", element)
  }

  static getContentEditable(element: BeamElement): string {
    return BeamElementHelper.getAttribute("contenteditable", element) || "inherit"
  }

  /**
   * Returns if an element is a textarea or an input elements with a text
   * based input type (text, email, date, number...)
   *
   * @param element {BeamHTMLElement} The DOM Element to check.
   * @return If the element is some kind of text input.
   */
  static isTextualInputType(element: BeamHTMLElement): boolean {
    const tag = element.tagName.toLowerCase()
    if (tag === "textarea") {
      return true
    } else if (tag === "input") {
      const types = [
        "text", "email", "password",
        "date", "datetime-local", "month",
        "number", "search", "tel",
        "time", "url", "week",
        // for legacy support
        "datetime"
      ]
      return types.includes((element as BeamHTMLInputElement).type)
    }
    return false
  }

  /**
   * Returns the text value for a given element, text value meaning either
   * the element's innerText or the input value
   *
   * @param el
   */
  static getTextValue(el: BeamElement): string {
    let textValue
    const tagName = el.tagName.toLowerCase()
    switch (tagName) {
      case "input": {
        const inputEl = el as BeamHTMLInputElement
        if (BeamElementHelper.isTextualInputType(inputEl)) {
          textValue = inputEl.value
        }
      }
        break
      case "textarea":
        textValue = (el as BeamHTMLTextAreaElement).value
        break
      default:
        textValue = (el as BeamHTMLElement).innerText
    }
    return textValue
  }

  static getBackgroundImageURL(element: BeamElement, win: BeamWindow): string | null {
    const style = win.getComputedStyle?.(element)
    const matchArray = style?.backgroundImage.match(/url\(([^)]+)/)
    if (matchArray && matchArray.length > 1) {
      return matchArray[1].replace(/('|")/g,"")
    }
  }

  /**
   * If element is background image, convert element to image element
   *
   * @static
   * @param {BeamElement} element
   * @param {BeamWindow<any>} win
   * @return {*}  {BeamHTMLElement}
   * @memberof BeamElementHelper
   */
  static parseBackgroundImageToImageElement(element: BeamElement, win: BeamWindow<any>): BeamHTMLElement {
    const backgroundImageURL = this.getBackgroundImageURL(element, win)
    if (!backgroundImageURL) {
      return null
    }

    const img = win.document.createElement("img")
    img.setAttribute("src", backgroundImageURL)
    return img
  }

  /**
   * If element has anchor tag as parent, wrap element in anchor tag
   *
   * @static
   * @param {BeamElement} element
   * @param {BeamWindow<any>} win
   * @return {*}  {BeamHTMLElement}
   * @memberof BeamElementHelper
   */
  static wrapElementInAnchor(element: BeamElement, win: BeamWindow<any>): BeamHTMLElement {
    const parentOfType = BeamElementHelper.hasParentOfType(element, "A")
    
    if (!parentOfType) {
      return null
    }

    const elementClode = element.cloneNode(true)
    const wrapper = win.document.createElement("a")
    wrapper.setAttribute("href", parentOfType.href)
    wrapper.appendChild(elementClode)
    return wrapper
  }
  /**
   * Returns parent of node type. Maximum allowed recursive depth is 10
   *
   * @private
   * @param {*} node target node to start at
   * @param {*} type parent type to search for
   * @param {number} [count=0] iteration count
   * @return {*} 
   * @memberof PointAndShootUI_native
   */
  static hasParentOfType(element, type, count = 0) {
    if (count > 10) return null
    if (type !== "BODY" && element?.tagName === "BODY") return null
    if (!element?.parentElement) return null
    if (type === element?.tagName) return element
    const newCount = count++
    return BeamElementHelper.hasParentOfType(element.parentElement, type, newCount)
  }
  /**
   * Parse Element based on it's styles and structure. Included conversions:
   * - Convert background image element to img element
   * - Wrapping element in anchor if parent is anchor tag
   *
   * @static
   * @param {BeamElement} element
   * @param {BeamWindow<any>} win
   * @return {*}  {BeamHTMLElement}
   * @memberof BeamElementHelper
   */
  static parseElementBasedOnStyles(element: BeamElement, win: BeamWindow<any>): BeamHTMLElement {
    const convertedToImage = BeamElementHelper.parseBackgroundImageToImageElement(element, win)
    if (convertedToImage) {
      return convertedToImage
    }

    // If we support embedding on the current location
    if (BeamElementHelper.isEmbed(element, win)) {
      // parse the element for embedding.
      const embedElement = BeamEmbedHelper.parseElementForEmbed(element, win)
      if (embedElement) {
        return embedElement
      }
    }

    const wrappedInAnchor = BeamElementHelper.wrapElementInAnchor(element, win)
    
    if (wrappedInAnchor) {
      return wrappedInAnchor
    }
    
    return element as BeamHTMLElement
  }

  /**
   * Determine whether or not an element is visible based on it's style
   * and bounding box if necessary
   *
   * @param element: {BeamElement}
   * @param win: {BeamWindow}
   * @return If the element is considered visible
   */
  // is slow, propertyvalue and boundingrect
  static isVisible(element: BeamElement, win: BeamWindow<any>): boolean {
    let visible = false

    if (element) {
      visible = true
      // We start by getting the element's computed style to check for any smoking guns
      const style = win.getComputedStyle?.(element)
      if (style) {
        visible = !(
            style.getPropertyValue("display") === "none"
            // Maybe hidden shouldn't be filtered out see the opacity comment
            || ["hidden", "collapse"].includes(style.getPropertyValue("visibility"))
            // The following heuristic isn't enough: twitter uses transparent inputs on top of their custom UI
            // (see theme selector in display settings for an example)
            // || style.opacity === '0'
            || (style.getPropertyValue("width") === "1px" && style.getPropertyValue("height") === "1px")
            || ["0px", "0"].includes(style.getPropertyValue("width"))
            || ["0px", "0"].includes(style.getPropertyValue("height"))
            // many clipPath values could cause the element to not be visible, but for now we only deal with single % values
            || (
                style.getPropertyValue("position") === "absolute"
                && style.getPropertyValue("clip").match(/rect\((0(px)?[, ]+){3}0px\)/)
            )
            || style.getPropertyValue("clip-path").match(/inset\(([5-9]\d|100)%\)/)
        )
      }

      // Still visible? Use boundingClientRect as a final check, it's expensive
      // so we should strive no to call it if it's unnecessary
      if (visible) {
        const rect: BeamRect = element.getBoundingClientRect()
        visible = (rect.width > 0 && rect.height > 0)
      }
    }
    return visible
  }

  /**
   * Returns true if element is Embed. Shorthand for calling `BeamEmbedHelper.isEmbed`
   *
   * @static
   * @param {BeamElement} element
   * @param {BeamWindow} win
   * @return {*}  {boolean}
   * @memberof BeamElementHelper
   */
  static isEmbed(element: BeamElement, win: BeamWindow): boolean {
    return BeamEmbedHelper.isEmbed(element, win)
  }

  /**
   * Returns whether an element is either a video or an audio element
   *
   * @param element
   */
  static isMedia(element: BeamElement): boolean {
    return  (
      ["video", "audio"].includes(element.tagName.toLowerCase()) || 
      Boolean(element.querySelectorAll("video").length) || 
      Boolean(element.querySelectorAll("audio").length)
    )
  }

  /**
   * Check whether an element is an image, or has a background-image url
   * the background image can be a data:uri
   *
   * @param element
   * @param win
   * @return If the element is considered visible
   */
  static isImage(element: BeamElement, win: BeamWindow): boolean {
    // currentSrc vs src
    if (
      ["img", "svg"].includes(element.tagName.toLowerCase()) ||
      Boolean(element.querySelectorAll("img").length) || 
      Boolean(element.querySelectorAll("svg").length)
    ) {
      return true
    }
    const style = win.getComputedStyle?.(element)
    const match = style?.backgroundImage.match(/url\(([^)]+)/)
    return !!match
  }

  /**
   * Returns whether an element is an image container, which means it can be an image
   * itself or recursively contain only image containers
   *
   * @param element
   * @param win
   */
  static isImageContainer(element: BeamElement, win: BeamWindow): boolean {
    if (BeamElementHelper.isImage(element, win)) {
      return true
    }
    if (element.children.length > 0) {
      return [...element.children].every(
          child => BeamElementHelper.isImageContainer(child, win)
      )
    }
    return false
  }

  /**
   * Returns the root svg element for the given element if any
   * @param element
   */
  static getSvgRoot(element: BeamElement): BeamElement {
    if (["body", "html"].includes(element.tagName.toLowerCase())) {
      return
    }
    if (element.tagName.toLowerCase() === "svg") {
      return element
    }
    if (element.parentElement) {
      return BeamElementHelper.getSvgRoot(element.parentElement)
    }
  }

  /**
   * Returns the first positioned element out of the element itself and its ancestors
   *
   * @param element
   * @param win
   */
  static getPositionedElement(element: BeamElement, win: BeamWindow): BeamElement {
    // Ignore body
    if (!element || element === win.document.body) {
      return
    }
    const style = win.getComputedStyle?.(element)

    if (element.parentElement && style?.position === "static") {
      return BeamElementHelper.getPositionedElement(element.parentElement, win)
    }
    if (style?.position !== "static") {
      return element
    }
  }

  /**
   * Return the first overflow escaping element. Since css overflow can be escaped by positioning
   * an element relative to the viewport, either by using `fixed`, or `absolute` in the case
   * there's no other positioning context
   *
   * @param element
   * @param clippingContainer
   * @param win
   */
  static getOverflowEscapingElement(element: BeamElement, clippingContainer: BeamElement, win: BeamWindow): BeamElement {
    // Ignore body
    if (!element || element === win.document.body) {
      return
    }
    const style = win.getComputedStyle?.(element)
    if (style) {
      switch (style.position) {
        case "absolute": {
          // If absolute, we need to make sure it's not within a positioned element already
          const positionedAncestor = BeamElementHelper.getPositionedElement(element.parentElement, win)
          if (positionedAncestor && positionedAncestor.contains(clippingContainer)) {
            return element
          }
          return element
        }
        case "fixed":
          // Fixed elements always escape overflow clipping
          return element
        default:
          return BeamElementHelper.getOverflowEscapingElement(
              element.parentElement, clippingContainer, win
          )
      }
    }
  }

  /**
   * Recursively look for the first ancestor element with an `overflow`, `clip`, or `clip-path
   * css property triggering clipping on the element
   *
   * @param element
   * @param win
   */
  static getClippingElement(element: BeamElement, win: BeamWindow): BeamElement {
    // Ignore body
    if (element === win.document.body) {
      return
    }
    const style = win.getComputedStyle?.(element)
    if (style) {
      if (
          style.getPropertyValue("overflow") === "visible"
          && style.getPropertyValue("overflow-x") === "visible"
          && style.getPropertyValue("overflow-y") === "visible"
          && style.getPropertyValue("clip") === "auto"
          && style.getPropertyValue("clip-path") === "none"
      ) {
        if (element.parentElement) {
          return BeamElementHelper.getClippingElement(element.parentElement, win)
        }
      } else {
        return element
      }
    } else {
      if (element.parentElement) {
        return BeamElementHelper.getClippingElement(element.parentElement, win)
      }
    }
    return
  }

  /**
   * Inspect the element itself and its ancestors and return the collection of elements
   * with clipping active due to the presence of `overflow`, `clip` or `clip-path` css properties
   *
   * @param element
   * @param win
   */
  static getClippingElements(element: BeamElement, win: BeamWindow<any>): BeamElement[] {
    const clippingElement = BeamElementHelper.getClippingElement(element, win)
    if (!clippingElement) {
      return []
    }
    if (clippingElement.parentElement && clippingElement.parentElement !== win.document.body) {
      return [
        clippingElement,
        ...BeamElementHelper.getClippingElements(clippingElement.parentElement, win)
      ]
    }
    return [clippingElement]
  }

  /**
   * Compute intersection of all the clipping areas of the given elements collection
   * the resulting area might extend infinitely in one of its dimensions
   *
   * @param elements
   * @param win
   */
  static getClippingArea(elements: BeamElement[], win: BeamWindow<any>): BeamRect {
    const areas: BeamRect[] = elements.map(el => {
      const style = win.getComputedStyle?.(el)
      if (style) {
        const overflowX = style.getPropertyValue("overflow-x") !== "visible"
        const overflowY = style.getPropertyValue("overflow-y") !== "visible"
        const bounds = el.getBoundingClientRect()
        if (overflowX && !overflowY) {
          return {x: bounds.x, width: bounds.width, y: -Infinity, height: Infinity}
        }
        if (overflowY && !overflowX) {
          return {y: bounds.y, height: bounds.height, x: -Infinity, width: Infinity}
        }
        return bounds
      }
    })

    return areas.reduce(
        (clippingArea, area) => (
            clippingArea
                ? BeamRectHelper.intersection(clippingArea, area)
                : area
        ), null
    )
  }

  /**
   * Returns the clipping containers which the element doesn't contain
   * @param element
   * @param win
   */
  static getClippingContainers(element: BeamElement, win: BeamWindow): BeamElement[] {
    return BeamElementHelper
        .getClippingElements(element, win)
        .filter(container => {
          const escapingElement = BeamElementHelper.getOverflowEscapingElement(element, container, win)
          return !escapingElement || escapingElement.contains(container)
        })
  }
  /**
   * Checks if target is 120% taller or 110% wider than window frame.
   *
   * @static
   * @param {DOMRect} bounds element bounds to check
   * @param {BeamWindow} win 
   * @return {*}  {boolean} true if either width or height is large
   * @memberof PointAndShootHelper
   */
   static isLargerThanWindow(bounds: DOMRect, win: BeamWindow): boolean {  
    const windowHeight = win.innerHeight
    const yPercent = (100 / windowHeight) * bounds.height
    const yIsLarge = yPercent > 110
    // If possible return early to skip the second win.innterWidth call
    if (yIsLarge) {
      return yIsLarge
    }
    
    const windowWidth = win.innerWidth
    const xPercent = (100 / windowWidth) * bounds.width
    const xIsLarge = xPercent > 110
    return xIsLarge
  }
}
