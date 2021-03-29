import {NativeUI} from "./NativeUI";
import {WebUI} from "./WebUI";

/**
 * UI that performs both Web and native UI.
 *
 * For debug purposes.
 */

export class BeamUI {

  webUi
  nativeUi

  constructor(webUi, nativeUI) {
    this.webUi = webUi
    this.nativeUi = nativeUI
    console.log(`Instantiated ${this}`)
  }

  point(el, x, y) {
    this.webUi.point(el)
    this.nativeUi.point(el, x, y)
  }

  unpoint(el) {
    this.webUi.unpoint(el)
    this.nativeUi.unpoint(el)
  }

  shoot(el, x, y, selected, submitCb) {
    this.webUi.shoot(el, x, y, selected, submitCb)
    this.nativeUi.shoot(el, x, y, selected, submitCb)
  }

  setFramesInfo(framesInfo) {
    this.nativeUi.setFramesInfos(framesInfo)
  }

  setScrollInfo(scrollInfo) {
    this.nativeUi.setScrollInfo(scrollInfo)
  }

  setResizeInfo(resizeInfo, selected) {
    this.nativeUi.setResizeInfo(resizeInfo, selected)
  }

  enterSelection(scrollWidth) {
    this.webUi.enterSelection(scrollWidth)
    this.nativeUi.enterSelection()
  }

  leaveSelection() {
    this.webUi.leaveSelection()
    this.nativeUi.leaveSelection()
  }

  selectAreas(i, selectedText, selectedHTML, textAreas) {
    this.webUi.selectAreas(textAreas)
    this.nativeUi.selectAreas(i, selectedText, selectedHTML, textAreas)
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

  static getInstance() {
    let instance
    try {
      const webUI = WebUI.getInstance()
      const nativeUI = NativeUI.getInstance()
      instance = webUI ? nativeUI ? new BeamUI(webUI, nativeUI) : webUI : nativeUI
      console.log(`BeamUI is ${instance}`)
    } catch (e) {
      console.error(e)
      instance = null
    }
    return instance
  }
}
