import { ContextMenuUI } from "./ContextMenuUI"
import {
  BeamEmbedContentSize,
  BeamLogCategory,
  BeamWindow,
  MessagePayload,
  Native
} from "@beam/native-beamtypes"
import { BeamLogger } from "@beam/native-utils"

export class ContextMenuUI_native implements ContextMenuUI {
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
   * @returns {ContextMenuUI_native}
   */
  static getInstance(win: BeamWindow): ContextMenuUI_native {
    let instance
    try {
      const native = Native.getInstance(win, "ContextMenu")
      instance = new ContextMenuUI_native(native)
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(e)
      instance = null
    }
    return instance
  }

  sendMenuInvoked(message: {}) {
    this.native.sendMessage("menuInvoked", message)
  }

  toString(): string {
    return this.constructor.name
  }
}
