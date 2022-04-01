import {
  BeamLogCategory,
  BeamWindow
} from "@beam/native-beamtypes"
import type { LinkMouseOverUI as LinkMouseOverUI } from "./LinkMouseOverUI"
import { BeamLogger } from "@beam/native-utils"

export class LinkMouseOver<UI extends LinkMouseOverUI> {
  win: BeamWindow
  logger: BeamLogger
  mouseOverAnchorElement = false

  /**
   * Singleton
   *
   * @type LinkMouseOver
   */
  static instance: LinkMouseOver<any>

  /**
   * @param win {(BeamWindow)}
   * @param ui {LinkMouseOverUI}
   */
  constructor(win: BeamWindow<any>, protected ui: UI) {
    this.win = win
    this.logger = new BeamLogger(win, BeamLogCategory.embedNode)
    this.registerEventListeners()
  }

  registerEventListeners(): void {
    this.win.addEventListener("mouseover", this.mouseover.bind(this))
    this.win.addEventListener("mouseout", this.mouseout.bind(this))
  }

  mouseover(event) {
    const anchorElement = this.findParentAnchorElement(event.target)
    if (!anchorElement || !anchorElement.href) {
      return
    }

    this.mouseOverAnchorElement = true

    const message = {
      url: anchorElement.href,
      target: anchorElement.target
    }

    this.ui.sendLinkMouseOver(message)
  }

  mouseout() {
    if (!this.mouseOverAnchorElement) {
      return
    }
    this.mouseOverAnchorElement = false
    this.ui.sendLinkMouseOut({})
  }

  findParentAnchorElement(element) {
    if (element == null || element == document.body) {
      return null
    }
    if (element.tagName == "A") {
      return element
    }
    return this.findParentAnchorElement(element.parentElement)
  }

  toString(): string {
    return this.constructor.name
  }
}
