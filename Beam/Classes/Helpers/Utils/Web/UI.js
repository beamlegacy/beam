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
   * @param el {HTMLElement}
   * @param x {number}
   * @param y {number}
   */
  point(el, x, y) {
  }

  /**
   * @param el {HTMLElement}
   */
  unpoint(el) {
  }

  /**
   * @param el {HTMLElement}
   */
  unshoot(el) {
  }

  hidePopup() {
  }

  /**
   * @param el {HTMLElement}
   * @param collected {any}
   */
  showStatus(el, collected) {
  }

  hideStatus() {
  }

  /**
   * Select an HTML element to be added to a card.
   *
   * @param el {HTMLElement} The selection event (click or touch).
   * @param x {number} Horizontal coordinate of click/touch
   * @param y {number} Vertical coordinate of click/touch
   * @param selectedEls {HTMLElement[]}
   * @param submitCb {Function}
   */
  shoot(el, x, y, selectedEls, submitCb) {
  }

  /**
   * @param framesInfo {FrameInfo[]}
   */
  setFramesInfo(framesInfo) {
  }

  /**
   * @param scrollInfo
   */
  setScrollInfo(scrollInfo) {
  }

  /**
   * @param resizeInfo {BeamSize}
   * @param els {HTMLElement[]}
   */
  setResizeInfo(resizeInfo, els) {
  }

  pinched(pinchInfo) {
  }
}
