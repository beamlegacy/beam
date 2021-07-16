import {PointAndShootUI} from "./PointAndShootUI"
import {Native} from "./Native"
import {WebEventsUI_native} from "./WebEventsUI_native"
import {
  BeamCollectedQuote,
  BeamElement,
  BeamElementMessagePayload,
  BeamHTMLElement,
  BeamMouseLocation,
  BeamNodeType,
  BeamQuoteId,
  BeamRange,
  BeamRect,
  BeamSelectionMessagePayload,
  BeamText,
} from "./BeamTypes"
import {Util} from "./Util"
import {BeamElementHelper} from "./BeamElementHelper";
import {BeamRectHelper} from "./BeamRectHelper";
import {PointAndShootHelper} from "./PointAndShootHelper";

export class PointAndShootUI_native extends WebEventsUI_native implements PointAndShootUI {
  /**
   * @param native {Native}
   */
  constructor(native: Native) {
    super(native)
  }

  /**
   * Update a given area's bounds with it's bounds and containerBounds
   *
   * @private
   * @param {*} area
   * @param {*} bounds
   * @param clippingArea
   * @return {*} {BeamRect}
   * @memberof PointAndShootUI_native
   */
  private setArea(area, bounds, clippingArea): BeamRect {
    let newArea

    if (area && bounds) {
      newArea = BeamRectHelper.boundingRect(area, bounds)
    } else if (bounds) {
      // No previous area, use bounds
      const { x, y, width, height } = bounds
      newArea = { x, y, width, height }
    }

    if (newArea && clippingArea) {
      newArea = BeamRectHelper.intersection(newArea, clippingArea)
    }

    return newArea
  }

  /**
   * Gets the visual bounds of a given element. If the element contains child nodes,
   * the sum of all child node bounds is used instead (recursively)
   *
   * Supported child node types are:
   *  - Element
   *  - Text
   *  See: https://developer.mozilla.org/en-US/docs/Web/API/Node/nodeType
   *
   * @param {BeamElement} el
   * @param {BeamRect} area
   * @param clippingArea
   * @return {*} {BeamRect}
   * @memberof PointAndShootUI_native
   */
  elementBounds(el: BeamElement, area?: BeamRect, clippingArea?: BeamRect): BeamRect {
    const { win } = this.native

    // Find svg root if any and use it for bounds calculation
    const svgRoot = BeamElementHelper.getSvgRoot(el)
    if (svgRoot) {
      el = svgRoot
    }

    // Make sure the element has something we're interested in
    if (!PointAndShootHelper.isMeaningfulOrChildrenAre(el, win)) {
      return
    }

    // Filter useful childNodes
    const childNodes = PointAndShootHelper.getMeaningfulChildNodes(el, win)

    // Get clipping area if previously undefined
    const computeClippingArea = el !== win.document.body && el !== win.document.documentElement
    if (!clippingArea && computeClippingArea) {
      const clippingContainers = BeamElementHelper.getClippingContainers(el, win)
      if (clippingContainers && clippingContainers.length > 0) {
        clippingArea = BeamElementHelper.getClippingArea(clippingContainers, win)
      }
    }

    // If it's an image or media, select the whole element
    const selectWholeElement = BeamElementHelper.isImage(el, win) || BeamElementHelper.isMedia(el)

    // We have meaningful children, inspect them and compute their bounds
    if (childNodes.length > 0 && !selectWholeElement) {

      for (const child of childNodes) {
        switch (child.nodeType) {
          case BeamNodeType.element:
            const childElement = child as BeamElement
            if (childElement.tagName.toLowerCase() === "svg") {
              let childBounds = childElement.getBoundingClientRect()
              area = this.setArea(area, childBounds, clippingArea)
            } else {
              const bounds = this.elementBounds(childElement, area, clippingArea)
              area = this.setArea(area, bounds, clippingArea)
            }
            break
          case BeamNodeType.text:
            const nodeRange = win.document.createRange()
            nodeRange.selectNode(child)
            let rangeBounds = nodeRange.getBoundingClientRect()
            if (rangeBounds.width > 0 && rangeBounds.height > 0) {
              area = this.setArea(area, rangeBounds, clippingArea)
            }
            break
        }
      }

      return area
    }

    // No meaningful childNodes, check the element itself
    if (PointAndShootHelper.isMeaningful(el, win)) {
      const elementBounds = el.getBoundingClientRect()
      area = this.setArea(area, elementBounds, clippingArea)
    }

    return area
  }

  /**
   * Checks if element and mouse coordinates overlap
   *
   * @private
   * @param {*} area
   * @param mouseLocation
   * @return {*}
   * @memberof PointAndShootUI_native
   */
  private hasRectAndMouseOverlap(area, mouseLocation) {
    // TODO: be way smarter about this logic
    // const xPercent = (100 / this.native.win.innerWidth) * area.width
    // const xIsLarge = xPercent > 80
    const yPercent = (100 / this.native.win.innerHeight) * area.height
    const yIsLarge = yPercent > 150
    if (yIsLarge) {
      return false
    }

    const graceDistance = 40

    const xMin = area.x - graceDistance
    const yMin = area.y - graceDistance
    const xMax = area.x + area.width + graceDistance
    const yMax = area.y + area.height + graceDistance

    const xIsInRange = Util.isNumberInRange(mouseLocation.x, xMin, xMax)
    const yIsInRange = Util.isNumberInRange(mouseLocation.y, yMin, yMax)
    return xIsInRange && yIsInRange
  }

  /**
   * Based on: https://css-tricks.com/snippets/jquery/calculate-distance-between-mouse-and-element/
   */
  calculateDistance(coordinate: number, areaCoord: number, areaSize: number) {
    const distance = coordinate - (areaCoord + areaSize / 2)
    // we want parallax to start when it snaps on the graceDistance
    const edge = areaSize / 2 + 40
    const distanceClamp = Util.clamp(distance, -edge, edge)
    const displacement = 10
    const mapped = Util.mapRangeToRange([-edge, edge], [-displacement, displacement], distanceClamp)
    return mapped
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
    const xOffset = this.calculateDistance(x, area.x, area.width)
    const yOffset = this.calculateDistance(y, area.y, area.height)
    return {
      areas: [area],
      html: el.outerHTML,
      quoteId,
      location: {
        x: location.x,
        y: location.y,
      },
      offset: { x: xOffset, y: yOffset }
    }
  }

  /**
   * Computes element bounds of a given selection range. Returns an array of rectangles which are computed to a polygon in the UI.
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
   * Mouse location is included in the return but defaulted to `{x: -1, y: -1}`
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

  cursorMessage(x: any, y: any) {
    const cursorPayload = { x, y }
    this.native.sendMessage("cursor", cursorPayload)
  }

  /**
   * Formats the message to be send to the UI based on element and mouse location.
   * Message is only send when mouse location and (child) element location overlap.
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
    } else {
      this.native.sendMessage("cursor", { x, y })
    }
  }

  cursor(x, y) {
    this.cursorMessage(x, y)
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
