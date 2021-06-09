import { PointAndShootUI } from "./PointAndShootUI"
import { Native } from "./Native"
import { WebEventsUI_native } from "./WebEventsUI_native"
import {
  BeamElement,
  BeamHTMLElement,
  BeamNodeType,
  BeamRect,
  BeamSelectionMessagePayload,
  BeamElementMessagePayload,
  BeamQuoteId,
  BeamMouseLocation,
  BeamCollectedQuote,
  BeamRange,
} from "./BeamTypes"
import { Util } from "./Util"

export class PointAndShootUI_native extends WebEventsUI_native implements PointAndShootUI {
  /**
   * @param native {Native}
   */
  constructor(native: Native) {
    super(native)
  }

  /**
   * Update a given area's bounds with it's childBounds and containerBounds
   *
   * @private
   * @param {*} area
   * @param {*} childBounds
   * @param {*} containerBounds
   * @return {*}  {BeamRect}
   * @memberof PointAndShootUI_native
   */
  private setArea(area, childBounds, containerBounds): BeamRect {
    return {
      x: Math.min(area.x, area.x + childBounds.x),
      y: Math.min(area.y, area.y + childBounds.y),
      width: Math.max(area.width, childBounds.x - containerBounds.x + childBounds.width),
      height: Math.max(area.height, childBounds.y - containerBounds.y + childBounds.height),
    }
  }

  /**
   * Gets the element bounds of a given element. If the element contains child nodes,
   * the sum of all child node bounds is used instead.
   *
   * Supported child node types are:
   *  - Element
   *  - Text
   *  See: https://developer.mozilla.org/en-US/docs/Web/API/Node/nodeType
   *
   * @private
   * @param {BeamElement} el
   * @return {*}  {BeamRect}
   * @memberof PointAndShootUI_native
   */
  private elementBounds(el: BeamElement): BeamRect {
    const containerBounds = el.getBoundingClientRect()
    // We only need to get first-level children
    const childNodes = el.childNodes

    if (childNodes.length > 0) {
      // Init rect with container offset
      let area: BeamRect = { x: containerBounds.x, y: containerBounds.y, width: 0, height: 0 }

      for (const child of childNodes) {
        switch (child.nodeType) {
          case BeamNodeType.element:
            let childBounds = (child as BeamElement).getBoundingClientRect()
            area = this.setArea(area, childBounds, containerBounds)
            break
          case BeamNodeType.text:
            const nodeRange = this.native.win.document.createRange()
            nodeRange.selectNode(child)
            let rangeBounds = nodeRange.getBoundingClientRect()
            area = this.setArea(area, rangeBounds, containerBounds)
            break
          case BeamNodeType.comment:
            this.log(`Skipping: ${child.nodeType} (Comment)`)
            break
          default:
            this.log(`Unsupported node type: ${child.nodeType}, skipping iteration`)
            break
        }
      }

      return area
    }

    return {
      x: containerBounds.x,
      y: containerBounds.y,
      width: containerBounds.width,
      height: containerBounds.height,
    }
  }

  /**
   * Checks if element and mouse coordinates overlap
   *
   * @private
   * @param {*} area
   * @param {*} location
   * @return {*}
   * @memberof PointAndShootUI_native
   */
  private hasRectAndMouseOverlap(area, location) {
    const xIsInRange = Util.isNumberInRange(location.x, area.x, area.x + area.width)
    const yIsInRange = Util.isNumberInRange(location.y, area.y, area.y + area.height)
    return xIsInRange && yIsInRange
  }

  /**
   * Formats the message to be send to the UI based on element and mouse location
   *
   * @private
   * @param {BeamQuoteId} quoteId
   * @param {BeamElement} el
   * @param {number} x page x value of mouse location
   * @param {number} y page y value of mouse location
   * @return {*}  {BeamElementMessagePayload}
   * @memberof PointAndShootUI_native
   */
  private elementAreaMessage(quoteId: BeamQuoteId, el: BeamElement, x: number, y: number): BeamElementMessagePayload {
    const area = this.elementBounds(el)
    const location = this.getMouseLocation(el, x, y)
    return {
      areas: [area],
      html: el.outerHTML,
      quoteId,
      location,
    }
  }

  /**
   * Computes element bounds of a given selection range. Returns an array of rectanges which are computed to a polygon in the UI.
   *
   * @private
   * @param {BeamRange} range
   * @return {*}  {BeamRect[]}
   * @memberof PointAndShootUI_native
   */
  private selectionBounds(range: BeamRange): BeamRect[] {
    const rangeRects = Array.from(range.getClientRects())
    return rangeRects.map((rangeRect) => {
      return {
        x: rangeRect.x,
        y: rangeRect.y,
        width: rangeRect.width,
        height: rangeRect.height,
      }
    })
  }

  /**
   * Formats the message to be send to the UI based on selection range.
   * Mouselocation is included in the return but defaulted to `{x: -1, y: -1}`
   *
   * @private
   * @param {*} quoteId
   * @param {BeamRange} range
   * @return {*}  {BeamSelectionMessagePayload}
   * @memberof PointAndShootUI_native
   */
  private selectionAreaMessage(quoteId, range: BeamRange): BeamSelectionMessagePayload {
    const text = range.toString()
    const html = Array.prototype.reduce.call(
      range.cloneContents().childNodes,
      (result, node) => result + (node.outerHTML || node.nodeValue),
      ""
    )
    const areas = this.selectionBounds(range)
    return {
      areas,
      text,
      html,
      quoteId,
      location: { x: -1, y: -1 },
    }
  }

  /**
   * Formats the message to be send to the UI based on selection range.
   *
   * @param {BeamCollectedQuote[]} ranges
   * @memberof PointAndShootUI_native
   */
  selectMessage(ranges: BeamCollectedQuote[]) {
    // TODO: Throttle
    const selectPayloads = ranges.map(({ quoteId, el }) => {
      return this.selectionAreaMessage(quoteId, el as BeamRange)
    })

    selectPayloads.forEach((selectPayload) => {
      this.native.sendMessage("select", selectPayload)
    })
  }

  /**
   * Formats the message to be send to the UI based on element and mouse location.
   *
   * @param quoteId
   * @param el {BeamHTMLElement}
   * @param {number} x page x value of mouse location
   * @param {number} y page y value of mouse location
   */
  shootMessage(quoteId: string, el: BeamHTMLElement, x: number, y: number) {
    const shootPayload = this.elementAreaMessage(quoteId, el, x, y)
    this.native.sendMessage("shoot", shootPayload)
  }

  /**
   * Formats the message to be send to the UI based on element and mouse location.
   * Message is only send when mouselocation and (child) element location overlap.
   *
   * @param {*} quoteId
   * @param {BeamElement} el
   * @param {number} x page x value of mouse location
   * @param {number} y page y value of mouse location
   * @param callback
   * @memberof PointAndShootUI_native
   */
  pointMessage(quoteId, el: BeamElement, x: number, y: number, callback) {
    const area = this.elementBounds(el)
    if (!area) {
      return
    }

    if (this.hasRectAndMouseOverlap(area, { x, y })) {
      const pointPayload = this.elementAreaMessage(quoteId, el, x, y)
      this.native.sendMessage("point", pointPayload)
      return
    }

    this.hidePoint(quoteId)
    callback()
  }

  /**
   * Handles point event
   *
   * @param {string} quoteId
   * @param {BeamHTMLElement} el
   * @param {number} x page x value of mouse location
   * @param {number} y page y value of mouse location
   * @param callback
   * @memberof PointAndShootUI_native
   */
  point(quoteId: string, el: BeamHTMLElement, x: number, y: number, callback) {
    this.pointMessage(quoteId, el, x, y, callback)
  }

  unpoint(el) {}

  hidePoint(quoteId = "quoteId") {
    this.native.sendMessage("hidePoint", quoteId)
  }

  /**
   * Handles select event
   *
   * @param {BeamCollectedQuote[]} ranges
   * @memberof PointAndShootUI_native
   */
  select(ranges: BeamCollectedQuote[]) {
    this.selectMessage(ranges)
  }

  unselect(selection) {}

  /**
   * Handles shoot event
   *
   * @param {string} quoteId
   * @param {BeamHTMLElement} el
   * @param {number} x page x value of mouse location
   * @param {number} y page y value of mouse location
   * @param {*} selectedEls
   * @memberof PointAndShootUI_native
   */
  shoot(quoteId: string, el: BeamHTMLElement, x: number, y: number, selectedEls) {
    /*
     * - Hide previous native popup if any
     * - Show native popup
     */
    this.shootMessage(quoteId, el, x, y)
  }

  unshoot(el: BeamHTMLElement) {}

  hidePopup() {}

  /**
   * Show the if a given was added to a card.
   */
  showStatus(el: BeamHTMLElement, collected) {
    // TODO: Send message to display native status as "collected" data
  }

  hideStatus() {
    // TODO: Send message to hide native status display
  }

  /**
   * Returns a relative computed mouse location for a given element
   *
   * @param {BeamElement} el HTML element
   * @param {number} x page x value of mouse location
   * @param {number} y page y value of mouse location
   * @return {*}
   * @memberof PointAndShootUI_native
   */
  getMouseLocation(el: BeamElement, x: number, y: number): BeamMouseLocation {
    const area = this.elementBounds(el)
    // limit min / max of mouse location to area bounds
    let clampedX = Util.clamp(x, area.x, area.x + area.width)
    let clampedY = Util.clamp(y, area.y, area.y + area.height)

    // return x / y position relative to element area
    return {
      x: clampedX - area.x,
      y: clampedY - area.y,
    }
  }

  setStatus(status) {
    this.native.sendMessage("setStatus", { status })
  }

  setResizeInfo(setResizeInfo) {
    setResizeInfo.selected = setResizeInfo.selected.map((item) => {
      const element = item.el
      const quoteId = item.quoteId
      if (element instanceof Range) {
        return this.selectionAreaMessage(quoteId, element as unknown as BeamRange)
      }
      return this.elementAreaMessage(quoteId, element, setResizeInfo.coordinates.x, setResizeInfo.coordinates.y)
    })
    super.setResizeInfo(setResizeInfo)
  }
}
