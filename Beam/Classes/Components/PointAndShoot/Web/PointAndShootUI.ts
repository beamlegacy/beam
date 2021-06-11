import { WebEventsUI } from "./WebEventsUI"
import { BeamCollectedQuote, BeamQuoteId, BeamRange } from "./BeamTypes"
import { BeamHTMLElement } from "./BeamTypes"

export interface PointAndShootUI extends WebEventsUI {
  cursor(x: any, y: any)
  hidePoint()

  /**
   * Calculate mouseLocation relative to element
   *
   * @param el {HTMLElement} The selection event (click or touch).
   * @param x {number} Horizontal coordinate of click/touch
   * @param y {number} Vertical coordinate of click/touch
   * @memberof PointAndShootUI
   */
  getMouseLocation(el, x, y)

  /**
   * Select HTML element to be drawn
   *
   * @param quoteId {BeamQuoteId} Beam quote identifier.
   * @param el {HTMLElement} The element hovered in collect mode.
   * @param x {number}
   * @param y {number}
   * @memberof PointAndShootUI
   */
  point(quoteId: string, el: BeamHTMLElement, x: number, y: number, callback)
  /**
   * Unselect point element
   *
   * @param el {HTMLElement}
   * @memberof PointAndShootUI
   */
  unpoint(el)

  /**
   * Select HTML selection to be drawn
   *
   * @param {BeamCollectedQuote[]} selectionRanges
   * @memberof PointAndShootUI
   */
  select(selectionRanges: BeamCollectedQuote[])

  /**
   * Unselect selection element
   *
   * @param {*} selection
   * @memberof PointAndShootUI
   */
  unselect(selection)

  /**
   * Select an HTML element to be added to a card.
   *
   * @param quoteId {BeamQuoteId} Beam quote identifier.
   * @param el {HTMLElement} The selection event (click or touch).
   * @param x {number} Horizontal coordinate of click/touch
   * @param y {number} Vertical coordinate of click/touch
   * @param collectedQuotes {BeamCollectedQuote[]}
   * @memberof PointAndShootUI
   */
  shoot(
    quoteId: BeamQuoteId,
    el: BeamHTMLElement | BeamRange,
    x: number,
    y: number,
    collectedQuotes: BeamCollectedQuote[]
  )

  /**
   * Unselect shoot element
   *
   * @param el {BeamHTMLElement}
   * @memberof PointAndShootUI
   */
  unshoot(el: BeamHTMLElement)

  /**
   * Hide popup ui
   *
   * @memberof PointAndShootUI
   */
  hidePopup()

  /**
   * Show status
   *
   * @param el {BeamHTMLElement}
   * @param collected {any}
   * @memberof PointAndShootUI
   */
  showStatus(el: BeamHTMLElement, collected)

  /**
   * Hide status
   *
   * @memberof PointAndShootUI
   */
  hideStatus()

  /**
   * @param status {"pointing"|"shooting"|"none"}
   * @memberof PointAndShootUI
   */
  setStatus(status)
}
