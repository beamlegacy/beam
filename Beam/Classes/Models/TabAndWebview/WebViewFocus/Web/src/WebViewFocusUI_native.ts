import { WebViewFocusUI } from "./WebViewFocusUI"
import {
  BeamLogCategory,
  BeamWindow,
  Native
} from "@beam/native-beamtypes"
import { BeamLogger } from "@beam/native-utils"

export class WebViewFocusUI_native implements WebViewFocusUI {
  logger: BeamLogger
  /**
   * @param native {Native}
   */
  constructor(protected native: Native<any>) {
    this.logger = new BeamLogger(this.native.win, BeamLogCategory.embedNode)
    this.logger.log(`${this.toString()} instantiated`)
  }

  /**
   *
   * @param win {BeamWindow}
   * @returns {WebViewFocusUI_native}
   */
  static getInstance(win: BeamWindow): WebViewFocusUI_native {
    let instance
    try {
      const native = Native.getInstance(win, "WebViewFocus")
      instance = new WebViewFocusUI_native(native)
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(e)
      instance = null
    }
    return instance
  }

  toString(): string {
    return this.constructor.name
  }
}
