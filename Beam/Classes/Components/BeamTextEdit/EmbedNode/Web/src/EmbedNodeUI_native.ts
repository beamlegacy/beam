import { EmbedNodeUI } from "./EmbedNodeUI"
import {
  BeamEmbedContentSize,
  BeamLogCategory,
  BeamWindow,
  MessagePayload,
  Native
} from "@beam/native-beamtypes"
import { BeamLogger } from "@beam/native-utils"

export class EmbedNodeUI_native implements EmbedNodeUI {
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
   * @returns {EmbedNodeUI_native}
   */
  static getInstance(win: BeamWindow): EmbedNodeUI_native {
    let instance
    try {
      const native = Native.getInstance(win, "EmbedNode")
      instance = new EmbedNodeUI_native(native)
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(e)
      instance = null
    }
    return instance
  }

  sendContentSize(sizing: BeamEmbedContentSize): void {
    this.native.sendMessage("contentSize", sizing as unknown as MessagePayload)
  }

  toString(): string {
    return this.constructor.name
  }
}
