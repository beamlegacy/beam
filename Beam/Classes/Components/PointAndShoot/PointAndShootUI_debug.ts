import {PointAndShootUI} from "./PointAndShootUI"
import {PointAndShootUI_native} from "./PointAndShootUI_native";
import {PointAndShootUI_web} from "./PointAndShootUI_web";
import {FrameInfo} from "./WebEventsUI";
import {BeamHTMLElement} from "./BeamTypes"

export class PointAndShootUI_debug implements PointAndShootUI {
  /**
   *
   * @param native {PointAndShootUI_native}
   * @param web {PointAndShootUI_web}
   */
  constructor(private native: PointAndShootUI_native, private web: PointAndShootUI_web) {
    this.native = native
    this.web = web
  }
  getMouseLocation(el: any, x: any, y: any) {
    this.web.getMouseLocation(el, x, y)
    this.native.getMouseLocation(el, x, y)
  }

  point(quoteId: string, el: BeamHTMLElement, x: number, y: number) {
    this.web.point(quoteId, el, x, y)
    this.native.point(quoteId, el, x, y)
  }

  unpoint(el) {
    this.web.unpoint(el)
    this.native.unpoint(el)
  }

  shoot(quoteId: string, el: BeamHTMLElement, x: number, y: number, selectedEls) {
    this.web.shoot(quoteId, el, x, y, selectedEls)
    this.native.shoot(quoteId, el, x, y, selectedEls)
  }

  unshoot(el: BeamHTMLElement) {
    this.web.unshoot(el)
    this.native.unshoot(el)
  }

  hidePopup() {
    this.web.hidePopup()
    this.native.hidePopup()
  }

  hideStatus() {
    this.web.hideStatus()
    this.native.hideStatus()
  }

  pinched(pinchInfo: any) {
    this.web.pinched(pinchInfo)
    this.native.pinched(pinchInfo)
  }

  setFramesInfo(framesInfo: FrameInfo[]) {
    this.web.setFramesInfo(framesInfo)
    this.native.setFramesInfo(framesInfo)
  }

  setOnLoadInfo() {
    this.web.setOnLoadInfo()
    this.native.setOnLoadInfo()
  }

  setResizeInfo(resizeInfo: any) {
    this.web.setResizeInfo(resizeInfo)
    this.native.setResizeInfo(resizeInfo)
  }

  setScrollInfo(scrollInfo: any) {
    this.web.setScrollInfo(scrollInfo)
    this.native.setScrollInfo(scrollInfo)
  }

  setStatus(status) {
    this.web.setStatus(status)
    this.native.setStatus(status)
  }

  showStatus(el: BeamHTMLElement, collected) {
    this.web.showStatus(el, collected)
    this.native.showStatus(el, collected)
  }

  enterSelection() {
    this.web.enterSelection()
    this.native.enterSelection()
  }

  leaveSelection() {
    this.web.leaveSelection()
    this.native.leaveSelection()
  }

  addTextSelection(selection) {
    this.web.addTextSelection(selection)
    this.native.addTextSelection(selection)
  }

  textSelected(selection) {
    this.web.textSelected(selection)
    this.native.textSelected(selection)
  }
}
