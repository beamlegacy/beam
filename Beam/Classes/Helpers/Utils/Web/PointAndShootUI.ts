import {WebEventsUI} from "./WebEventsUI"

export interface PointAndShootUI extends WebEventsUI {
  /**
   * @param el {HTMLElement} The element hovered in collect mode.
   * @param x {number}
   * @param y {number}
   */
  point(el, x, y)

  /**
   * @param el {HTMLElement}
   */
  unpoint(el)

  /**
   * Select an HTML element to be added to a card.
   *
   * @param el {HTMLElement} The selection event (click or touch).
   * @param x {number} Horizontal coordinate of click/touch
   * @param y {number} Vertical coordinate of click/touch
   * @param selectedEls {HTMLElement[]}
   * @param submitCb {Function}
   */
  shoot(el, x, y, selectedEls, submitCb)

  /**
   * @param el {HTMLElement}
   */
  unshoot(el)

  enterSelection()

  leaveSelection()

  hidePopup()

  /**
   * @param el {BeamHTMLElement}
   * @param collected {any}
   */
  showStatus(el, collected)

  hideStatus()

  /**
   * @param status {"pointing"|"shooting"|"none"}
   */
  setStatus(status)
}
