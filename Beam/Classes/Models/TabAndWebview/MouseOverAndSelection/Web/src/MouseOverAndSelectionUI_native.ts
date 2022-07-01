import { MouseOverAndSelectionUI } from "./MouseOverAndSelectionUI"
import {
  BeamLogCategory,
  BeamWindow,
  Native
} from "@beam/native-beamtypes"
import { BeamLogger } from "@beam/native-utils"

export class MouseOverAndSelectionUI_native implements MouseOverAndSelectionUI {
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
   * @returns {MouseOverAndSelectionUI_native}
   */
  static getInstance(win: BeamWindow): MouseOverAndSelectionUI_native {
    let instance
    try {
      const native = Native.getInstance(win, "MouseOverAndSelection")
      instance = new MouseOverAndSelectionUI_native(native)
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

  private selectionChangePayload: string = ""

  sendSelectionChange(message: { selection: string }) {
    if (message.selection != this.selectionChangePayload) {
      this.selectionChangePayload = message.selection
      this.native.sendMessage("selectionChange", message)
    }
  }

  sendSelectionAndShortcutHit(message: { selection: string }) {
    this.native.sendMessage("selectionAndShortcutHit", message)
  }

  toString(): string {
    return this.constructor.name
  }
}
