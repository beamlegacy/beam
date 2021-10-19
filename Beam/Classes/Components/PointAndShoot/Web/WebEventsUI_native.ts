import {Native} from "../../../Helpers/Utils/Web/Native"
import {FrameInfo, WebEventsUI} from "./WebEventsUI"
import {BeamWindow} from "../../../Helpers/Utils/Web/BeamTypes"

export class WebEventsUI_native implements WebEventsUI {
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
   * @returns {WebEventsUI_native}
   */
  static getInstance(win: BeamWindow): WebEventsUI_native {
    let instance
    try {
      const native = Native.getInstance(win)
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
