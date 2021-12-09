import { EmbedNodeUI } from "./EmbedNodeUI"
import {
  BeamEmbedContentSize,
  BeamWindow
} from "../../../../Helpers/Utils/Web/BeamTypes"

export class EmbedNodeUI_web implements EmbedNodeUI {
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
   * @returns {EmbedNodeUI_native}
   */
  static getInstance(win: BeamWindow) {
    let instance
    try {
      instance = new EmbedNodeUI_web(win)
    } catch (e) {
      console.error(e)
      instance = null
    }
    return instance
  }

  protected log(...args) {
    console.log(this.toString(), args)
  }

  sendContentSize(_sizing: BeamEmbedContentSize): void {
    throw new Error("Method not implemented.")
  }

  toString() {
    return this.constructor.name
  }
}
