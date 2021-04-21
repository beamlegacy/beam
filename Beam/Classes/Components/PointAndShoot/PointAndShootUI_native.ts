import {PointAndShootUI} from "./PointAndShootUI"
import {Native} from "./Native";
import {WebEventsUI_native} from "./WebEventsUI_native";

export class PointAndShootUI_native extends WebEventsUI_native implements PointAndShootUI {
  /**
   * @param native {Native}
   */
  constructor(native: Native) {
    super(native)
  }

  pointMessage(el, x, y) {
    const pointBounds = el.getBoundingClientRect()
    const pointPayload = {
      area: {
        x: pointBounds.x,
        y: pointBounds.y,
        width: pointBounds.width,
        height: pointBounds.height
      },
      html: el.innerHTML,
      location: {x, y}
    }
    this.native.sendMessage("point", pointPayload)
  }

  /**
   * @param el {HTMLElement}
   * @param x {number}
   * @param y {number}
   */
  shootMessage(el, x, y) {
    const shootBounds = el.getBoundingClientRect()
    const shootMessage = {
      area: {
        x: shootBounds.x,
        y: shootBounds.y,
        width: shootBounds.width,
        height: shootBounds.height
      },
      html: el.innerHTML,
      location: {x, y}
    }
    this.native.sendMessage("shoot", shootMessage)
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
