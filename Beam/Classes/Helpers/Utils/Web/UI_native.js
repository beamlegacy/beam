import {UI} from "./UI"
import {Native} from "./Native"
import {TextSelectorUI_native} from "./TextSelectorUI_native"
import {PointAndShootUI_native} from "./PointAndShootUI_native"

export class UI_native extends UI {

  /**
   * @param native {Native}
   */
  constructor(native) {
    super(new PointAndShootUI_native(), new TextSelectorUI_native(native))
    this.native = native
    console.log(`${this} instantiated`)
  }

  toString() {
    return this.constructor.name
  }

  /**
   *
   * @param win {BeamWindow}
   * @returns {UI_native}
   */
  static getInstance(win) {
    let instance
    try {
      instance = new UI_native(Native.getInstance(win))
    } catch (e) {
      console.error(e)
      instance = null
    }
    return instance
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

  /**
   * @param el {HTMLElement}
   * @param x {number}
   * @param y {number}
   */
  point(el, x, y) {
    this.pointMessage(el, x, y)
  }

  unpoint(_el) {
    this.native.sendMessage("point", null)
  }

  unshoot(el) {
    // TODO: message to un-shoot
  }

  hidePopup() {
    // TODO: Hide popup message?
  }

  shoot(el, x, y, selected, _submitCb) {
    /*
     * - Hide previous native popup if any
     * - Show native popup
     */
    this.shootMessage(el, x, y)
    // TODO: handle native popup result (probably not using submitCb, but rather through native explicitly invoking JS directly?)
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

  /**
   * @param framesInfo {FrameInfo[]}
   */
  setFramesInfo(framesInfo) {
    const framesWithOrigin = framesInfo.map(frameInfo => Object.assign(frameInfo, {origin: this.native.origin}))
    this.native.sendMessage("frameBounds", {frames: framesWithOrigin})
  }

  setScrollInfo(scrollInfo) {
    this.native.sendMessage("onScrolled", scrollInfo)
  }

  setResizeInfo(resizeInfo, selected) {
    this.native.sendMessage("resize", resizeInfo)
    for (const someSelected of selected) {
      this.shootMessage(someSelected, -1, -1)
    }
  }

  pinched(pinchInfo) {
    this.native.sendMessage("pinch", pinchInfo)
  }
}
