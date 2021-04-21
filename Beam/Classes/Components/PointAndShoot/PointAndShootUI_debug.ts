import {PointAndShootUI} from "./PointAndShootUI"
import {PointAndShootUI_native} from "./PointAndShootUI_native";
import {PointAndShootUI_web} from "./PointAndShootUI_web";
import {FrameInfo} from "./WebEventsUI";

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

  point(el, x, y) {
    this.web.point(el, x, y)
    this.native.point(el, x, y)
  }

  unpoint(el) {
    this.web.unpoint(el)
    this.native.unpoint(el)
  }

  shoot(el, x, y, selected, submitCb) {
    this.web.shoot(el, x, y, selected, submitCb)
    this.native.shoot(el, x, y, selected, submitCb)
  }

  unshoot(el) {
    this.web.unshoot(el)
    this.native.unshoot(el)
  }

  enterSelection() {
    this.web.enterSelection()
    this.native.enterSelection()
  }

  hidePopup() {
    this.web.hidePopup()
    this.native.hidePopup()
  }

  hideStatus() {
    this.web.hideStatus()
    this.native.hideStatus()
  }

  leaveSelection() {
    this.web.leaveSelection()
    this.native.leaveSelection()
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

  showStatus(el, collected) {
    this.web.showStatus(el, collected)
    this.native.showStatus(el, collected)
  }
}
