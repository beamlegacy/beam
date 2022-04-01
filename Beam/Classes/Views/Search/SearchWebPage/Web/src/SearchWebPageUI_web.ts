import { SearchWebPageUI } from "./SearchWebPageUI"
import {
  BeamLogCategory,
  BeamWindow
} from "@beam/native-beamtypes"
import { BeamLogger } from "@beam/native-utils"

export class SearchWebPageUI_web implements SearchWebPageUI {
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
   * @returns {SearchWebPageUI_native}
   */
  static getInstance(win: BeamWindow) {
    let instance
    try {
      instance = new SearchWebPageUI_web(win)
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(e)
      instance = null
    }
    return instance
  }

  webPageSearch(payload: { currentResult?: number; totalResults?: number; positions?: undefined[]; height?: number; incompleteSearch?: boolean; currentSelected?: boolean }) {
    throw new Error("Method not implemented.")
  }
  webSearchCurrentSelection(selection: string) {
    throw new Error("Method not implemented.")
  }

  toString() {
    return this.constructor.name
  }
}
