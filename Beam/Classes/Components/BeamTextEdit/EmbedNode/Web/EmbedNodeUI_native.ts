import { Native } from "../../../../Helpers/Utils/Web/Native"
import { EmbedNodeUI } from "./EmbedNodeUI"
import {
  BeamEmbedContentSize,
  BeamWindow,
  MessagePayload
} from "../../../../Helpers/Utils/Web/BeamTypes"

export class EmbedNodeUI_native implements EmbedNodeUI {
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
   * @returns {EmbedNodeUI_native}
   */
  static getInstance(win: BeamWindow): EmbedNodeUI_native {
    let instance
    try {
      const native = Native.getInstance(win, "EmbedNode")
      instance = new EmbedNodeUI_native(native)
    } catch (e) {
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
