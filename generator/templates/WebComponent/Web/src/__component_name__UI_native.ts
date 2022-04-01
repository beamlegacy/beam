import { __component_name__UI } from "./__component_name__UI"
import {
  BeamEmbedContentSize,
  BeamLogCategory,
  BeamWindow,
  MessagePayload,
  Native
} from "@beam/native-beamtypes"
import { BeamLogger } from "@beam/native-utils"

export class __component_name__UI_native implements __component_name__UI {
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
   * @returns {__component_name__UI_native}
   */
  static getInstance(win: BeamWindow): __component_name__UI_native {
    let instance
    try {
      const native = Native.getInstance(win, "__component_name__")
      instance = new __component_name__UI_native(native)
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(e)
      instance = null
    }
    return instance
  }

  /**
   * Example of UI function that calls the Swift MessageHandler
   *
   * @param {BeamEmbedContentSize} sizing
   * @memberof __component_name__UI_native
   */
  sendContentSize(sizing: BeamEmbedContentSize): void {
    this.native.sendMessage("contentSize", sizing as unknown as MessagePayload)
  }

  toString(): string {
    return this.constructor.name
  }
}
