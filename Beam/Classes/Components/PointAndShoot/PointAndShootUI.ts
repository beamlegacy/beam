import {WebEventsUI} from "./WebEventsUI"
import {TextSelection} from "./TextSelection";
import {BeamHTMLElement} from "./BeamTypes"

export interface PointAndShootUI extends WebEventsUI {
  /**
   * Calculate mouseLocation relative to element
   *
   * @param el {HTMLElement} The selection event (click or touch).
   * @param x {number} Horizontal coordinate of click/touch
   * @param y {number} Vertical coordinate of click/touch
   */
  getMouseLocation(el, x, y)
  /**
   * @param quoteId {quoteId} Beam quote identifier. 
   * @param el {HTMLElement} The element hovered in collect mode.
   * @param x {number}
   * @param y {number}
   */
  point(quoteId: string, el: BeamHTMLElement, x: number, y: number)

  /**
   * @param el {HTMLElement}
   */
  unpoint(el)

  /**
   * Select an HTML element to be added to a card.
   *
   * @param quoteId {quoteId} Beam quote identifier. 
   * @param el {HTMLElement} The selection event (click or touch).
   * @param x {number} Horizontal coordinate of click/touch
   * @param y {number} Vertical coordinate of click/touch
   * @param selectedEls {HTMLElement[]}
   */
  shoot(quoteId: string, el: BeamHTMLElement, x: number, y: number, selectedEls)

  /**
   * @param el {BeamHTMLElement}
   */
  unshoot(el: BeamHTMLElement)

  hidePopup()

  /**
   * @param el {BeamHTMLElement}
   * @param collected {any}
   */
  showStatus(el: BeamHTMLElement, collected)

  hideStatus()

  /**
   * @param status {"pointing"|"shooting"|"none"}
   */
  setStatus(status)

  enterSelection()

  leaveSelection()

  /**
   * @param selection {TextSelection}
   */
  textSelected(selection: TextSelection)

  /**
   * @param selection {TextSelection}
   */
  addTextSelection(selection: TextSelection)
}
