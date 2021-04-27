import {PointAndShootUI} from "./PointAndShootUI"
import {Native} from "./Native"
import {WebEventsUI_native} from "./WebEventsUI_native"
import {BeamElement, BeamHTMLElement, BeamNodeType, BeamRect} from "./BeamTypes"

interface AreaMessage {
  area: BeamRect  // Should be a polygon later
  html: string
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
      let childBounds: any
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

  private areaMessage(el: BeamElement, x: number, y: number) {
    const pointPayload: PointMessagePayload = {
      area: this.elementBounds(el),
      html: el.outerHTML,
      location: {x, y}
    }
    return pointPayload
  }

  pointMessage(el: BeamElement, x: number, y: number) {
    const pointPayload: PointMessagePayload = this.areaMessage(el, x, y)
    this.native.sendMessage("point", pointPayload)
  }

  /**
   * @param el {HTMLElement}
   * @param x {number}
   * @param y {number}
   */
  shootMessage(el: BeamHTMLElement, x: number, y: number) {
    const shootPayload: ShootMessagePayload = this.areaMessage(el, x, y)
    this.native.sendMessage("shoot", shootPayload)
  }

  point(el, x, y) {
    this.pointMessage(el, x, y)
  }

  unpoint(el) {
    // setStatus("none") from native is enough for native
  }

  shoot(el, x, y, selected, _submitCb) {
    /*
     * - Hide previous native popup if any
     * - Show native popup
     */
    this.shootMessage(el, x, y)
    // TODO: handle native popup result (probably not using submitCb, but rather through native explicitly invoking JS directly?)
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

  setStatus(status) {
    this.native.sendMessage("setStatus", {status})
  }

  setResizeInfo(resizeInfo: any) {
    super.setResizeInfo(resizeInfo)
    for (const someSelected of resizeInfo.selected) {
      this.shootMessage(someSelected, -1, -1)
    }
  }
}
