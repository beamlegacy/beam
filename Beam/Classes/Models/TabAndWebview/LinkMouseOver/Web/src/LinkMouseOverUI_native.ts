import { LinkMouseOverUI } from "./LinkMouseOverUI"
import {
  BeamLogCategory,
  BeamWindow,
  Native
} from "@beam/native-beamtypes"
import { BeamLogger } from "@beam/native-utils"

export class LinkMouseOverUI_native implements LinkMouseOverUI {
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
   * @returns {LinkMouseOverUI_native}
   */
  static getInstance(win: BeamWindow): LinkMouseOverUI_native {
    let instance
    try {
      const native = Native.getInstance(win, "LinkMouseOver")
      instance = new LinkMouseOverUI_native(native)
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(e)
      instance = null
    }
    return instance
  }

  sendLinkMouseOut(arg0: {}) {
    this.native.sendMessage("linkMouseOut", {})
  }

  sendLinkMouseOver(message: { url: any; target: any }) {
    this.native.sendMessage("linkMouseOver", message)
  }

  toString(): string {
    return this.constructor.name
  }
}
