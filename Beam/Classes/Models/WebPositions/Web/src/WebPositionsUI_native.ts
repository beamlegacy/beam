import {WebPositionsUI} from "./WebPositionsUI"
import {BeamLogCategory, BeamWindow, FrameInfo, Native} from "@beam/native-beamtypes"
import { BeamLogger } from "@beam/native-utils"

export class WebPositionsUI_native implements WebPositionsUI {
  logger: BeamLogger
  /**
   * @param native {Native}
   */
  constructor(protected native: Native<any>) {
    this.logger = new BeamLogger(native.win, BeamLogCategory.webpositions)
    this.logger.log(`${this.toString()} instantiated`)
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
      // eslint-disable-next-line no-console
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
      this.native.sendMessage("resize", resizeInfo)
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
