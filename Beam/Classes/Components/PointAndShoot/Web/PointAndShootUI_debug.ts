import { BeamElement, BeamRangeGroup, BeamShootGroup } from "./BeamTypes"
import { PointAndShootUI } from "./PointAndShootUI"
import { PointAndShootUI_native } from "./PointAndShootUI_native"
import { PointAndShootUI_web } from "./PointAndShootUI_web"
import { FrameInfo } from "./WebEventsUI"

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
  isTypingOnWebView(isTypingOnWebView: boolean): void {
      throw new Error("Method not implemented.")
  }
  hasSelection(hasSelection: boolean) {
    throw new Error("Method not implemented.")
  }
  setFramesInfo(framesInfo: FrameInfo[]) {
    throw new Error("Method not implemented.")
  }
  setScrollInfo(scrollInfo: any) {
    throw new Error("Method not implemented.")
  }
  setResizeInfo(resizeInfo: any) {
    throw new Error("Method not implemented.")
  }
  setOnLoadInfo(framesInfo: FrameInfo[]) {
    throw new Error("Method not implemented.")
  }
  pinched(pinchInfo: any) {
    throw new Error("Method not implemented.")
  }
  pointBounds(pointTarget?: BeamShootGroup) {
    throw new Error("Method not implemented.")
  }
  shootBounds(shootTargets: BeamShootGroup[]) {
    throw new Error("Method not implemented.")
  }
  selectBounds(rangeGroups: BeamRangeGroup[]) {
    throw new Error("Method not implemented.")
  }
}
