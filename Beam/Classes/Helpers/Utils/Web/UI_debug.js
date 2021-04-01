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
  webUi

  /**
   * @type UI_native
   */
  nativeUi

  /**
   *
   * @param nativeUI {UI_native}
   * @param webUi {UI_web}
   */
  constructor(nativeUI, webUi) {
    super(new PointAndShootUI_debug(nativeUI, webUi), new TextSelectorUI_debug(nativeUI, webUi))
    this.nativeUi = nativeUI
    this.webUi = webUi
    console.log(`Instantiated ${this}`)
  }

  point(el, x, y) {
    this.pointAndShoot.point(el, x, y)
  }

  unpoint(el) {
    this.pointAndShoot.unpoint(el)
  }

  shoot(el, x, y, selected, submitCb) {
    this.pointAndShoot.shoot(el, x, y, selected, submitCb)
  }

  setFramesInfo(framesInfo) {
    this.nativeUi.setFramesInfo(framesInfo)
  }

  setScrollInfo(scrollInfo) {
    this.nativeUi.setScrollInfo(scrollInfo)
  }

  setResizeInfo(resizeInfo, selected) {
    this.nativeUi.setResizeInfo(resizeInfo, selected)
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
    this.webUi.hideStatus()
    this.nativeUi.hideStatus()
  }

  hidePopup() {
    this.webUi.hidePopup()
    this.nativeUi.hidePopup()
  }

  toString() {
    return "" + this.webUi ? this.nativeUi ? this.webUi + "+" + this.nativeUi : this.webUi : this.nativeUi
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
}
