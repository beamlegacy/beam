import { GeolocationUI } from "./GeolocationUI"
import {
  BeamLogCategory,
  BeamWindow
} from "@beam/native-beamtypes"
import { BeamLogger } from "@beam/native-utils"

export class GeolocationUI_web implements GeolocationUI {
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
  listenerAdded(): void {
    throw new Error("Method not implemented.")
  }
  listenerRemmoved(): void {
    throw new Error("Method not implemented.")
  }

  /**
   *
   * @param win {BeamWindow}
   * @returns {GeolocationUI_native}
   */
  static getInstance(win: BeamWindow) {
    let instance
    try {
      instance = new GeolocationUI_web(win)
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(e)
      instance = null
    }
    return instance
  }

  toString() {
    return this.constructor.name
  }
}
