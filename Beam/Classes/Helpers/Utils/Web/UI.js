export class FrameInfo {
  /**
   * @type string
   */
  href

  /**
   * @type {BeamRect}
   */
  bounds
}

export class UI {
  /**
   * @type TextSelectorUI
   */
  textSelector

  /**
   * @type PointAndShootUI
   */
  pointAndShoot

  /**
   * @param pointAndShoot {PointAndShootUI}
   * @param textSelector {TextSelectorUI}
   */
  constructor(pointAndShoot, textSelector) {
    this.pointAndShoot = pointAndShoot
    this.textSelector = textSelector
  }

  /**
   * @param el {BeamHTMLElement}
   * @param x {number}
   * @param y {number}
   */
  point(el, x, y) {
  }

  /**
   * @param el {BeamHTMLElement} The element to unpoint (required for web UI)
   */
  unpoint(el) {
  }

  /**
   * @param el {BeamHTMLElement}
   */
  unshoot(el) {
  }

  hidePopup() {
  }

  /**
   * @param el {BeamHTMLElement}
   * @param collected {any}
   */
  showStatus(el, collected) {
  }

  hideStatus() {
  }

  /**
   * Select an HTML element to be added to a card.
   *
   * @param el {BeamHTMLElement} The selection event (click or touch).
   * @param x {number} Horizontal coordinate of click/touch
   * @param y {number} Vertical coordinate of click/touch
   * @param selectedEls {BeamHTMLElement[]}
   * @param submitCb {Function({string})}
   */
  shoot(el, x, y, selectedEls, submitCb) {
  }

  /**
   * @param framesInfo {FrameInfo[]}
   */
  setFramesInfo(framesInfo) {
  }

  /**
   * @param scrollInfo {}
   */
  setScrollInfo(scrollInfo) {
  }

  /**
   * @param resizeInfo {BeamSize}
   * @param els {BeamHTMLElement[]}
   */
  setResizeInfo(resizeInfo, els) {
  }

  setOnLoadInfo() {
  }

  pinched(pinchInfo) {
  }

  /**
   * @param status {"pointing"|"shooting"|"none"}
   */
  setStatus(status) {
  }
}
