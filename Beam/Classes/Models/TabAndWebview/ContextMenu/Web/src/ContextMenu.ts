import {
  BeamElement,
  BeamLogCategory,
  BeamUIEvent,
  BeamWindow
} from "@beam/native-beamtypes"
import type { ContextMenuUI as ContextMenuUI } from "./ContextMenuUI"
import { BeamLogger } from "@beam/native-utils"

enum Invocation {
  Page = 1 << 0,
  TextSelection = 1 << 1,
  Link = 1 << 2,
  Image = 1 << 3,
  Ignored = 1 << 4
}

export class ContextMenu<UI extends ContextMenuUI> {
  win: BeamWindow
  logger: BeamLogger

  /**
   * Singleton
   *
   * @type ContextMenu
   */
  static instance: ContextMenu<any>

  /**
   * @param win {(BeamWindow)}
   * @param ui {ContextMenuUI}
   */
  constructor(win: BeamWindow<any>, protected ui: UI) {
    this.win = win
    this.logger = new BeamLogger(win, BeamLogCategory.embedNode)
    this.registerEventListeners()
  }

  registerEventListeners(): void {
    this.win.addEventListener("contextmenu", this.onContextMenu.bind(this))
  }

  onContextMenu(event: BeamUIEvent) {
    const message = this.menuInvokedMessageForTarget(event.target)
    this.ui.sendMenuInvoked(message)
  }
  
  menuInvokedMessageForTarget(target: BeamElement) {
    const [ elements, invocations ] = this.elementsAndInvocationType(target)

    var message: { invocations: Invocation, parameters: any } = {
      invocations: invocations,
      parameters: {}
    }

    var parameters: any = {}
    
    if ((invocations & Invocation.TextSelection) != 0) {
      parameters = { ...parameters, contents: this.win.document.getSelection().toString() }
    }
    if ((invocations & Invocation.Link) != 0) {
      parameters = { ...parameters, href: elements[0].href ?? elements[1].href }
    }
    if ((invocations & Invocation.Image) != 0) {
      parameters = { ...parameters, src: elements[0].src ?? elements[1].src }
    }

    message.parameters = parameters

    return message
  }

  findLinkWithinParents(element: BeamElement) {
    var parent = element.parentElement
    var isLink = parent.tagName == "A"
    while (!isLink && parent != this.win.document.body) {
      parent = parent.parentElement
      isLink = parent.tagName == "A"
    }
    return isLink ? parent : null
  }

  elementsAndInvocationType(element: BeamElement, invocation?: Invocation): [BeamElement[], Invocation] {
    if (element == null || element == this.win.document.body) {
      return [[element], Invocation.Page]
    }
    if (element.tagName == "VIDEO" || element.tagName == "AUDIO" || element.tagName == "INPUT" || element.tagName == "TEXTAREA") {
      return [[element], Invocation.Ignored]
    }
    if (element.tagName == "A") {
      return [[element], Invocation.Link]
    }
    if (element.tagName == "IMG") {
      // is this image contained within a link ?
      var link = this.findLinkWithinParents(element)
      if (link) {
        return [[element, link], Invocation.Link | Invocation.Image]
      } else {
        return [[element], Invocation.Image]
      }
    }
    const selection = this.win.document.getSelection()
    if (selection != null && element.contains(selection.anchorNode) && selection.toString()) {
      // does this text selection is surrounded by a link ?
      var link = this.findLinkWithinParents(element)
      if (link) {
        return [[element, link], Invocation.Link | Invocation.TextSelection]
      } else {
        return [[element], Invocation.TextSelection]
      }
    }
    return this.elementsAndInvocationType(element.parentElement, Invocation.Page)
  }

  toString(): string {
    return this.constructor.name
  }
}
