import {UI_native} from "./UI_native"
import {UI_web} from "./UI_web"
import {UI} from "./UI"
import {TextSelectorUI_debug} from "./TextSelectorUI_debug"
import {PointAndShootUI_debug} from "./PointAndShootUI_debug"

/**
 * UI that performs both Web and native UI.
 *
 * For debug purposes.
 */
export class UI_debug extends UI {

  /**
   * @type UI_web
   */
  web

  /**
   * @type UI_native
   */
  native

  /**
   *
   * @param native {UI_native}
   * @param web {UI_web}
   */
  constructor(native, web) {
    super(new PointAndShootUI_debug(native, web), new TextSelectorUI_debug(native, web))
    this.native = native
    this.web = web
    console.log(`${this.toString()} instantiated`)
  }

  point(el, x, y) {
    this.pointAndShoot.point(el, x, y)
  }

  unpoint() {
    this.pointAndShoot.unpoint(el)
  }

  shoot(el, x, y, selected, submitCb) {
    this.pointAndShoot.shoot(el, x, y, selected, submitCb)
  }

  unshoot(el) {
    this.pointAndShoot.unshoot(el)
  }

  setFramesInfo(framesInfo) {
    this.native.setFramesInfo(framesInfo)
    this.web.setFramesInfo(framesInfo)
  }

  setScrollInfo(scrollInfo) {
    this.native.setScrollInfo(scrollInfo)
    this.web.setScrollInfo(scrollInfo)
  }

  setResizeInfo(resizeInfo, selected) {
    this.native.setResizeInfo(resizeInfo, selected)
    this.web.setResizeInfo(resizeInfo, selected)
  }

  setOnLoadInfo() {
    this.native.setOnLoadInfo()
    this.web.setOnLoadInfo()
  }

  enterSelection(scrollWidth) {
    this.textSelector.enterSelection(scrollWidth)
  }

  leaveSelection() {
    this.textSelector.leaveSelection()
  }

  addTextSelection(selection) {
    this.textSelector.addTextSelection(selection)
  }

  textSelected(selection) {
    this.textSelector.textSelected(selection)
  }

  hideStatus() {
    this.native.hideStatus()
    this.web.hideStatus()
  }

  hidePopup() {
    this.native.hidePopup()
    this.web.hidePopup()
  }

  toString() {
    return "" + this.web ? this.native ? this.web + "+" + this.native : this.web : this.native
  }

  /**
   *
   * @param win {BeamWindow|Window}
   * @returns {UI_debug|UI_web|UI_native}
   */
  static getInstance(win) {
    let instance
    try {
      const webUI = UI_web.getInstance(win)
      const nativeUI = UI_native.getInstance(win)
      instance = webUI ? nativeUI ? new UI_debug(nativeUI, webUI) : webUI : nativeUI
      console.log(`BeamUI is ${instance}`)
    } catch (e) {
      console.error(e)
      instance = null
    }
    return instance
  }

  setStatus(status) {
    this.native.setStatus(status)
    this.web.setStatus(status)
  }
}
