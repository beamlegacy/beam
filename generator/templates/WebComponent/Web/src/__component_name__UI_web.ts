import { __component_name__UI } from "./__component_name__UI"
import {
  BeamEmbedContentSize,
  BeamLogCategory,
  BeamWindow
} from "@beam/native-beamtypes"
import { BeamLogger } from "@beam/native-utils"

export class __component_name__UI_web implements __component_name__UI {
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
    this.logger.log(`${this.toString()} instantiated`)
  }

  /**
   *
   * @param win {BeamWindow}
   * @returns {__component_name__UI_native}
   */
  static getInstance(win: BeamWindow) {
    let instance
    try {
      instance = new __component_name__UI_web(win)
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
  sendContentSize(_sizing: BeamEmbedContentSize): void {
    throw new Error("Method not implemented.")
  }

  toString() {
    return this.constructor.name
  }
}
