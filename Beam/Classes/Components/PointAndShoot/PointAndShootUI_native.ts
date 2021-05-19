import {PointAndShootUI} from "./PointAndShootUI"
import {Native} from "./Native"
import {WebEventsUI_native} from "./WebEventsUI_native"
import {BeamElement, BeamHTMLElement, BeamNodeType, BeamRect} from "./BeamTypes"
import {Util} from "./Util"

interface AreaMessage {
  area: BeamRect  // Should be a polygon later
  html: string
  quoteId: any
  location: { x: number, y: number }
}

export interface PointMessagePayload extends AreaMessage {
}

export interface ShootMessagePayload extends AreaMessage {
}

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

  private areaMessage(quoteId, el: BeamElement, x: number, y: number): PointMessagePayload {
    const area = this.elementBounds(el)
    const mouse = this.getMouseLocation(el, x, y)
    const html = el.outerHTML
    return {area, html, quoteId, location: {...mouse}}
  }

  pointMessage(quoteId, el: BeamElement, x: number, y: number) {
    const pointPayload: PointMessagePayload = this.areaMessage(quoteId, el, x, y)
    this.native.sendMessage("point", pointPayload)
  }

  /**
   * @param quoteId
   * @param el {HTMLElement}
   * @param x {number}
   * @param y {number}
   */
  shootMessage(quoteId: string, el: BeamHTMLElement, x: number, y: number) {
    const shootPayload: ShootMessagePayload = this.areaMessage(quoteId, el, x, y)
    this.native.sendMessage("shoot", shootPayload)
  }

  point(quoteId: string, el: BeamHTMLElement, x: number, y: number) {
    this.pointMessage(quoteId, el, x, y)
  }

  unpoint(el) {
    // setStatus("none") from native is enough for native
  }

  shoot(quoteId: string, el: BeamHTMLElement, x: number, y: number, selectedEls) {
    /*
     * - Hide previous native popup if any
     * - Show native popup
     */
    this.shootMessage(quoteId, el, x, y)
  }

  unshoot(el: BeamHTMLElement) {
  }

  hidePopup() {
    // TODO: Hide popup message?
  }

  /**
   * Show the if a given was added to a card.
   */
  showStatus(el: BeamHTMLElement, collected) {
    // TODO: Send message to display native status as "collected" data
  }

  hideStatus() {
    // TODO: Send message to hide native status display
  }

  getMouseLocation(el: BeamElement, x: number, y: number) {
    const area = this.elementBounds(el)
    // limit min / max of mouse location to area bounds
    let clampedX = Util.clamp(x, area.x, area.x + area.width)
    let clampedY = Util.clamp(y, area.y, area.y + area.height)

    // return x / y position relative to element area
    return {
      x: clampedX - area.x,
      y: clampedY - area.y
    }
  }

  setStatus(status) {
    this.native.sendMessage("setStatus", {status})
  }

  setResizeInfo(setResizeInfo) {
    setResizeInfo.selected = setResizeInfo.selected.map(element => {
      const quoteId = element.dataset[setResizeInfo.datasetKey]
      return this.areaMessage(quoteId, element, setResizeInfo.coordinates.x, setResizeInfo.coordinates.y)
    })
    super.setResizeInfo(setResizeInfo)
  }

  enterSelection() {
    // TODO: enterSelection message?
  }

  leaveSelection() {
    // this.log("leaveSelection")
    // TODO: leaveSelection message?
  }

  addTextSelection(selection) {
    // TODO: Throttle
    this.native.sendMessage("textSelection", selection)
  }

  textSelected(selection) {
    this.native.sendMessage("textSelected", selection)
  }
}
