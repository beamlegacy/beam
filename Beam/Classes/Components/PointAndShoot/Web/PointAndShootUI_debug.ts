import {BeamCollectedQuote} from "./BeamTypes"
import {PointAndShootUI} from "./PointAndShootUI"
import {PointAndShootUI_native} from "./PointAndShootUI_native"
import {PointAndShootUI_web} from "./PointAndShootUI_web"
import {FrameInfo} from "./WebEventsUI"
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

  cursor(x: any, y: any) {
    throw new Error("Method not implemented.")
  }

  select(selection: BeamCollectedQuote[]) {
    this.web.select(selection)
    this.native.select(selection)
  }

  unselect(selection: any) {
    this.web.unselect(selection)
    this.native.unselect(selection)
  }

  getMouseLocation(el: any, x: any, y: any) {
    this.web.getMouseLocation(el, x, y)
    this.native.getMouseLocation(el, x, y)
  }

  point(quoteId: string, el: BeamHTMLElement, x: number, y: number, callback): void {
    this.web.point(quoteId, el, x, y)
    this.native.point(quoteId, el, x, y, callback)
  }

  unpoint(el): void {
    this.web.unpoint(el)
    this.native.unpoint(el)
  }

  shoot(quoteId: string, el: BeamHTMLElement, x: number, y: number, selectedEls): void {
    this.web.shoot(quoteId, el, x, y, selectedEls)
    this.native.shoot(quoteId, el, x, y, selectedEls)
  }

  unshoot(el: BeamHTMLElement): void {
    this.web.unshoot(el)
    this.native.unshoot(el)
  }

  hidePopup(): void {
    this.web.hidePopup()
    this.native.hidePopup()
  }

  hideStatus(): void {
    this.web.hideStatus()
    this.native.hideStatus()
  }

  pinched(pinchInfo: any): void {
    this.web.pinched(pinchInfo)
    this.native.pinched(pinchInfo)
  }

  setFramesInfo(framesInfo: FrameInfo[]): void {
    this.web.setFramesInfo(framesInfo)
    this.native.setFramesInfo(framesInfo)
  }

  setOnLoadInfo(framesInfo: FrameInfo[]): void {
    this.web.setOnLoadInfo()
    this.native.setOnLoadInfo(framesInfo)
  }

  setResizeInfo(resizeInfo: any): void {
    this.web.setResizeInfo(resizeInfo)
    this.native.setResizeInfo(resizeInfo)
  }

  setScrollInfo(scrollInfo: any): void {
    this.web.setScrollInfo(scrollInfo)
    this.native.setScrollInfo(scrollInfo)
  }

  setStatus(status): void {
    this.web.setStatus(status)
    this.native.setStatus(status)
  }

  showStatus(el: BeamHTMLElement, collected): void {
    this.web.showStatus(el, collected)
    this.native.showStatus(el, collected)
  }

  enterSelection(): void {
    this.web.enterSelection()
  }

  leaveSelection(): void {
    this.web.leaveSelection()
  }

  addTextSelection(selection): void {
    this.web.addTextSelection(selection)
  }
}
