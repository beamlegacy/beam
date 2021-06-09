import {Native} from "./Native"
import {FrameInfo, WebEventsUI} from "./WebEventsUI"
import {BeamWindow} from "./BeamTypes";

export class WebEventsUI_native implements WebEventsUI {
  /**
   * @param native {Native}
   */
  constructor(protected native: Native) {
    this.log(`${this.toString()} instantiated`)
  }

  protected log(...args) {
    console.log(`${this.toString()}: `, args)
  }

  /**
   *
   * @param win {BeamWindow}
   * @returns {WebEventsUI_native}
   */
  static getInstance(win: BeamWindow) {
    let instance
    try {
      const native = Native.getInstance(win);
      instance = new WebEventsUI_native(native)
    } catch (e) {
      console.error(e)
      instance = null
    }
    return instance
  }

  /**
   * @param framesInfo {FrameInfo[]}
   */
  setFramesInfo(framesInfo: FrameInfo[]) {
    this.native.sendMessage("frameBounds", {frames: framesInfo})
  }

  setScrollInfo(scrollInfo) {
    this.native.sendMessage("scroll", scrollInfo)
  }

  setResizeInfo(resizeInfo) {
    this.native.sendMessage("resize", resizeInfo)
  }

  setOnLoadInfo() {
    this.native.sendMessage("onLoad", null)
  }

  pinched(pinchInfo) {
    this.native.sendMessage("pinch", pinchInfo)
  }

  toString() {
    return this.constructor.name
  }
}
