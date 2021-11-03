import {WebPositionsUI} from "./WebPositionsUI"
import {BeamWindow, FrameInfo} from "../../../Helpers/Utils/Web/BeamTypes"

export class WebEventsUI_web implements WebPositionsUI {
  protected prefix = "__ID__"

  protected readonly lang: string

  protected readonly win: BeamWindow

  /**
   */
  constructor(win: BeamWindow) {
    const doc = win.document
    const navigatorLanguage = navigator.language.substring(0, 2)
    const documentLanguage = doc.documentElement.lang
    this.lang = navigatorLanguage || documentLanguage
    this.log(`${this.toString()} instantiated`)
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

  protected log(...args) {
    console.log(this.toString(), args)
  }

  toString() {
    return this.constructor.name
  }
}
