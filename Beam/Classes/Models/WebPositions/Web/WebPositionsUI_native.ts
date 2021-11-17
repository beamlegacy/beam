import {Native} from "../../../Helpers/Utils/Web/Native"
import {WebPositionsUI} from "./WebPositionsUI"
import {BeamWindow, FrameInfo} from "../../../Helpers/Utils/Web/BeamTypes"

export class WebPositionsUI_native implements WebPositionsUI {
  /**
   * @param native {Native}
   */
  constructor(protected native: Native<any>) {
    this.log(`${this.toString()} instantiated`)
  }

  protected log(...args): void {
    console.log(`${this.toString()}: `, args)
  }

  /**
   *
   * @param win {BeamWindow}
   * @returns {WebPositionsUI_native}
   */
  static getInstance(win: BeamWindow): WebPositionsUI_native {
    let instance
    try {
      const native = Native.getInstance(win, "webPositions")
      instance = new WebPositionsUI_native(native)
    } catch (e) {
      console.error(e)
      instance = null
    }
    return instance
  }

  /**
   * @param framesInfo {FrameInfo[]}
   */
  setFramesInfo(framesInfo: FrameInfo[]): void {
    this.native.sendMessage("frameBounds", { frames: framesInfo })
  }

  setScrollInfo(scrollInfo): void {
    this.native.sendMessage("scroll", scrollInfo)
  }

  setResizeInfo(resizeInfo): void {
    // Nothing to do here
  }

  setOnLoadInfo(framesInfo: FrameInfo[]): void {
    this.native.sendMessage("onLoad", { frames: framesInfo })
  }

  pinched(pinchInfo): void {
    this.native.sendMessage("pinch", pinchInfo)
  }

  toString(): string {
    return this.constructor.name
  }
}
