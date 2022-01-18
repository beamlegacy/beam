import {WebPositionsUI} from "./WebPositionsUI"
import {BeamLogCategory, BeamWindow, FrameInfo} from "../../../Helpers/Utils/Web/BeamTypes"
import { BeamLogger } from "../../../Helpers/Utils/Web/BeamLogger"

export class WebEventsUI_web implements WebPositionsUI {
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
    this.logger = new BeamLogger(win, BeamLogCategory.webpositions)
    this.logger.log(`${this.toString()} instantiated`)
  }

  /**
   *
   * @param win {BeamWindow}
   * @returns {WebEventsUI_native}
   */
  static getInstance(win: BeamWindow) {
    let instance
    try {
      instance = new WebEventsUI_web(win)
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(e)
      instance = null
    }
    return instance
  }

  /**
   * @param framesInfo {FrameInfo[]}
   */
  setFramesInfo(framesInfo: FrameInfo[]) {
    // Nothing to do for a web UI
  }

  setScrollInfo(scrollInfo) {
    // Nothing to do for a web UI
  }

  setResizeInfo(resizeInfo) {
    // Nothing to do for a web UI
  }

  setOnLoadInfo() {
    // Nothing to do for a web UI
  }

  pinched(pinchInfo) {
    // Nothing to do for a web UI
  }

  toString() {
    return this.constructor.name
  }
}
