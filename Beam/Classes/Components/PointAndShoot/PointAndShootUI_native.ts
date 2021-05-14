import {PointAndShootUI} from "./PointAndShootUI"
import {Native} from "./Native"
import {WebEventsUI_native} from "./WebEventsUI_native"
import {BeamElement, BeamHTMLElement, BeamNodeType, BeamRect} from "./BeamTypes"
import { Util } from "./Util"

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

  private elementBounds(el: BeamElement) {
    const containerBounds = el.getBoundingClientRect()
    const area = new BeamRect(containerBounds.x, containerBounds.y) // Init with container offset
    // We only need to get first-level children
    for (const child of el.childNodes) {
      let childBounds: any = {
        x: 0,
        y: 0,
        width: 0,
        height: 0
      }
      switch (child.nodeType) {
        case BeamNodeType.element:
          childBounds = (child as BeamElement).getBoundingClientRect()
          break
        case BeamNodeType.text:
          const nodeRange = this.native.win.document.createRange()
          nodeRange.selectNode(child)
          childBounds = nodeRange.getBoundingClientRect()
          break
      }
      area.x = Math.min(area.x, area.x + childBounds.x)
      area.y = Math.min(area.y, area.y + childBounds.y)
      area.width = Math.max(area.width, childBounds.x - containerBounds.x + childBounds.width)
      area.height = Math.max(area.height, childBounds.y - containerBounds.y + childBounds.height)
    }
    return area
  }

  private areaMessage(quoteId, el: BeamElement, x: number, y: number) {
    const area = this.elementBounds(el)
    const mouse = this.getMouseLocation(el, x, y)
    const pointPayload: PointMessagePayload = {
      area,
      html: el.outerHTML,
      quoteId: quoteId,
      location: {
        ...mouse
      }
    }
    return pointPayload
  }

  pointMessage(quoteId, el: BeamElement, x: number, y: number) {
    const pointPayload: PointMessagePayload = this.areaMessage(quoteId, el, x, y)
    this.native.sendMessage("point", pointPayload)
  }

  /**
   * @param el {HTMLElement}
   * @param x {number}
   * @param y {number}
   */
  shootMessage(quoteId, el: BeamHTMLElement, x: number, y: number) {
    const shootPayload: ShootMessagePayload = this.areaMessage(quoteId, el, x, y)
    this.native.sendMessage("shoot", shootPayload)
  }

  point(quoteId, el, x, y) {
    this.pointMessage(quoteId, el, x, y)
  }

  unpoint(el) {
    // setStatus("none") from native is enough for native
  }

  shoot(quoteId, el, x, y, selected) {
    /*
     * - Hide previous native popup if any
     * - Show native popup
     */
    this.shootMessage(quoteId, el, x, y)
  }

  unshoot(el) {
  }

  enterSelection() {
  }

  leaveSelection() {
  }

  hidePopup() {
    // TODO: Hide popup message?
  }

  /**
   * Show the if a given was added to a card.
   */
  showStatus(el, collected) {
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
}
