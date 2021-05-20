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
  BeamCollectedNote,
  BeamRange,
} from "./BeamTypes"
import {Util} from "./Util"

export class PointAndShootUI_native extends WebEventsUI_native implements PointAndShootUI {
  /**
   * @param native {Native}
   */
  constructor(native: Native) {
    super(native)
  }

  private elementBounds(el: BeamElement): BeamRect {
    const containerBounds = el.getBoundingClientRect()
    let area: BeamRect = {x: containerBounds.x, y: containerBounds.y, width: 0, height: 0} // Init with container offset
    const childNodes = el.childNodes  // We only need to get first-level children
    if (childNodes.length > 0) {
      for (const child of childNodes) {
        let childBounds: BeamRect
        switch (child.nodeType) {
          case BeamNodeType.element:
            childBounds = (child as BeamElement).getBoundingClientRect()
            break
          case BeamNodeType.text:
            const nodeRange = this.native.win.document.createRange()
            nodeRange.selectNode(child)
            childBounds = nodeRange.getBoundingClientRect()
            break
          default:
            throw new Error(`Unsupported node type: ${child.nodeType}`)
        }
        area.x = Math.min(area.x, area.x + childBounds.x)
        area.y = Math.min(area.y, area.y + childBounds.y)
        area.width = Math.max(area.width, childBounds.x - containerBounds.x + childBounds.width)
        area.height = Math.max(area.height, childBounds.y - containerBounds.y + childBounds.height)
      }
    } else {
      area = {x: containerBounds.x, y: containerBounds.y, width: containerBounds.width, height: containerBounds.height}
    }
    return area
  }

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
      location: {x: -1, y: -1},
    }
  }

  pointMessage(quoteId, el: BeamElement, x: number, y: number) {
    const pointPayload = this.elementAreaMessage(quoteId, el, x, y)
    this.native.sendMessage("point", pointPayload)
  }

  selectMessage(ranges: BeamCollectedNote[]) {
    // TODO: Throttle
    const selectPayloads = ranges.map(({quoteId, el}) => {
      return this.selectionAreaMessage(quoteId, el as BeamRange)
    })

    selectPayloads.forEach((selectPayload) => {
      this.native.sendMessage("select", selectPayload)
    })
  }

  /**
   * @param quoteId
   * @param el {BeamHTMLElement}
   * @param x {number}
   * @param y {number}
   */
  shootMessage(quoteId: string, el: BeamHTMLElement, x: number, y: number) {
    console.log(el);
    const shootPayload = this.elementAreaMessage(quoteId, el, x, y)
    this.native.sendMessage("shoot", shootPayload)
  }

  point(quoteId: string, el: BeamHTMLElement, x: number, y: number) {
    this.pointMessage(quoteId, el, x, y)
  }

  unpoint(el) {}

  select(ranges: BeamCollectedNote[]) {
    this.selectMessage(ranges)
  }

  unselect(selection) {}

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
