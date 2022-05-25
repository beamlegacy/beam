import {
  BeamLogCategory,
  BeamWindow
} from "@beam/native-beamtypes"
import type { MouseOverAndSelectionUI as MouseOverAndSelectionUI } from "./MouseOverAndSelectionUI"
import { BeamLogger } from "@beam/native-utils"

export class MouseOverAndSelection<UI extends MouseOverAndSelectionUI> {
  win: BeamWindow
  logger: BeamLogger
  mouseOverAnchorElement = false

  /**
   * Singleton
   *
   * @type MouseOverAndSelection
   */
  static instance: MouseOverAndSelection<any>

  /**
   * @param win {(BeamWindow)}
   * @param ui {MouseOverAndSelectionUI}
   */
  constructor(win: BeamWindow<any>, protected ui: UI) {
    this.win = win
    this.logger = new BeamLogger(win, BeamLogCategory.embedNode)
    this.registerEventListeners()
  }

  registerEventListeners(): void {
    this.win.addEventListener("mouseover", this.mouseover.bind(this))
    this.win.addEventListener("mouseout", this.mouseout.bind(this))
    this.win.document.addEventListener("selectionchange", this.selectionchange.bind(this))
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

  selectionchange() {
    var selection = document.getSelection().toString()
    const message = { selection: selection }
    this.ui.sendSelectionChange(message)
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
