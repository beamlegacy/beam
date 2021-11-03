import {BeamRangeGroup, BeamShootGroup, FrameInfo} from "../../../Helpers/Utils/Web/BeamTypes"
import {PointAndShootUI} from "./PointAndShootUI"
import {PointAndShootUI_native} from "./PointAndShootUI_native"
import {PointAndShootUI_web} from "./PointAndShootUI_web"

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
  prefix: string
  typingOnWebView(_isTypingOnWebView: boolean): void {
    throw new Error("Method not implemented.")
  }
  clearSelection(_id: string): void {
    throw new Error("Method not implemented.")
  }
  hasSelection(_hasSelection: boolean): void {
    throw new Error("Method not implemented.")
  }
  setFramesInfo(_framesInfo: FrameInfo[]): void {
    throw new Error("Method not implemented.")
  }
  setScrollInfo(_scrollInfo: unknown): void {
    throw new Error("Method not implemented.")
  }
  setResizeInfo(_resizeInfo: unknown): void {
    throw new Error("Method not implemented.")
  }
  setOnLoadInfo(_framesInfo: FrameInfo[]): void {
    throw new Error("Method not implemented.")
  }
  pinched(_pinchInfo: unknown): void {
    throw new Error("Method not implemented.")
  }
  pointBounds(_pointTarget?: BeamShootGroup): void {
    throw new Error("Method not implemented.")
  }
  shootBounds(_shootTargets: BeamShootGroup[]): void {
    throw new Error("Method not implemented.")
  }
  selectBounds(_rangeGroups: BeamRangeGroup[]): void {
    throw new Error("Method not implemented.")
  }
}
