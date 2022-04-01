import {
  BeamHTMLElement,
  BeamLogCategory,
  BeamWindow
} from "@beam/native-beamtypes"
import type { WebViewFocusUI as WebViewFocusUI } from "./WebViewFocusUI"
import { BeamLogger } from "@beam/native-utils"

export class WebViewFocus<UI extends WebViewFocusUI> {
  win: BeamWindow
  logger: BeamLogger
  lastFocusedElement: BeamHTMLElement

  /**
   * Singleton
   *
   * @type WebViewFocus
   */
  static instance: WebViewFocus<any>

  /**
   * @param win {(BeamWindow)}
   * @param ui {WebViewFocusUI}
   */
  constructor(win: BeamWindow<any>, protected ui: UI) {
    this.win = win
    this.logger = new BeamLogger(win, BeamLogCategory.embedNode)
    this.win.addEventListener("focus", this.focusDidChange.bind(this))
  }

  focusDidChange(_event) {
    this.lastFocusedElement = this.win.document.activeElement
  }

  refocusLastElement() {
    const element = this.lastFocusedElement
    if (element) {
      element.focus()
    }
  }

  toString(): string {
    return this.constructor.name
  }
}
