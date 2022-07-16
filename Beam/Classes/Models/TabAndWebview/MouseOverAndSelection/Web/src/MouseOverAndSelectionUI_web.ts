import { MouseOverAndSelectionUI } from "./MouseOverAndSelectionUI"
import {
  BeamLogCategory,
  BeamWindow
} from "@beam/native-beamtypes"
import { BeamLogger } from "@beam/native-utils"

export class MouseOverAndSelectionUI_web implements MouseOverAndSelectionUI {
  protected prefix = "__ID__"

  protected readonly lang: string

  protected readonly win: BeamWindow
  logger: BeamLogger

  /**
   */
  constructor(win: BeamWindow) {
    const doc = win.document
    const navigatorLanguage = navigator.language.substring(0, 2)
    const documentLanguage = doc.documentElement.lang
    this.lang = navigatorLanguage || documentLanguage
    this.logger = new BeamLogger(win, BeamLogCategory.embedNode)
  }

  /**
   *
   * @param win {BeamWindow}
   * @returns {MouseOverAndSelectionUI_native}
   */
  static getInstance(win: BeamWindow) {
    let instance
    try {
      instance = new MouseOverAndSelectionUI_web(win)
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(e)
      instance = null
    }
    return instance
  }

  sendLinkMouseOut(arg0: {}) {}

  sendLinkMouseOver(message: { url: any; target: any }) {}

  sendSelectionChange(message: { selection: string }) {}

  sendSelectionAndShortcutHit(message: { selection: string }) {}

  toString() {
    return this.constructor.name
  }
}
