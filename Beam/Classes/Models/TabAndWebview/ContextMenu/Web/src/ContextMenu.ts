import {
  BeamElement,
  BeamLogCategory,
  BeamUIEvent,
  BeamWindow
} from "@beam/native-beamtypes"
import type { ContextMenuUI as ContextMenuUI } from "./ContextMenuUI"
import { BeamLogger } from "@beam/native-utils"

enum Invocation {
  Page,
  TextSelection,
  Link,
  Image,
  LinkPlusImage
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
    const [ elements, invocation ] = this.elementsAndInvocationType(target)

    var message: { invocation: Invocation, parameters: any } = {
      invocation: invocation,
      parameters: {}
    }
    
    switch (invocation) {
      case Invocation.Page:
        break // no need to add any additional parameters
      case Invocation.TextSelection:
        const selection = this.win.document.getSelection().toString()
        message.parameters = { contents: selection }
        break
      case Invocation.Link:
        message.parameters = { href: elements[0].href }
        break
      case Invocation.Image:
        message.parameters = { src: elements[0].src }
        break
      case Invocation.LinkPlusImage:
        const image = elements[0]
        const link = elements[1]
        message.parameters = { href: link.href, src: image.src }
        break
    }

    return message
  }

  elementsAndInvocationType(element: BeamElement, invocation?: Invocation): [BeamElement[], Invocation] {
    if (element == null || element == this.win.document.body) {
      return [[element], Invocation.Page]
    }
    if (element.tagName == "A") {
      return [[element], Invocation.Link]
    }
    if (element.tagName == "IMG") {
      // is this image contained within a link ?
      var link = element.parentElement
      var isLink = link.tagName == "A"
      while (!isLink && link != this.win.document.body) {
        link = link.parentElement
        isLink = link.tagName == "A"
      }
      if (isLink) {
        return [[element, link], Invocation.LinkPlusImage]
      } else {
        return [[element], Invocation.Image]
      }
    }
    const selection = this.win.document.getSelection()
    if (selection != null && element.contains(selection.anchorNode) && selection.toString()) {
      return [[element], Invocation.TextSelection]
    }
    return this.elementsAndInvocationType(element.parentElement, Invocation.Page)
  }

  toString(): string {
    return this.constructor.name
  }
}
