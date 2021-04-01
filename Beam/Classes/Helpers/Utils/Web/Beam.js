export class BeamSize {
  /**
   * @type {number}
   */
  width

  /**
   * @type {number}
   */
  height
}

export class BeamRect extends BeamSize {
  /**
   * @type {number}
   */
  x

  /**
   * @type {number}
   */
  y
}
export class BeamElement {
  classList

  /**
   * @param el {HTMLElement}
   */
  appendChild(el) {
  }

  /**
   * @param el {HTMLElement}
   */
  removeChild(el) {}
}

export class BeamBody extends BeamElement {
  /**
   * @type String
   */
  baseURI

  /**
   * @type number
   */
  scrollWidth

  /**
   * @type number
   */
  offsetWidth

  /**
   * @type number
   */
  clientWidth

  /**
   * @type number
   */
  scrollHeight

  /**
   * @type number
   */
  offsetHeight

  /**
   * @type number
   */
  clientHeight
}

export class BeamDocument {
  /**
   * @type {HTMLHtmlElement}
   */
  documentElement

  /**
   * @type BeamBody
   */
  body

  /**
   * @param tag {string}
   */
  createElement(tag) {
  }

  /**
   *
   * @param eventName {String}
   * @param cb {Function}
   */
  addEventListener(eventName, cb) {
  }

  /**
   * @return {Selection}
   */
  getSelection() {
  }

  /**
   * @param selector {string}
   * @return {HTMLElement[]}
   */
  querySelectorAll(selector) {
  }
}

export class BeamVisualViewport {
  /**
   * @type {number}
   */
  offsetTop

  /**
   * @type {number}
   */
  pageTop

  /**
   * @type {number}
   */
  offsetLeft

  /**
   * @type {number}
   */
  pageLeft

  /**
   * @type {number}
   */
  width

  /**
   * @type {number}
   */
  height

  /**
   * @type {number}
   */
  scale

  addEventListener(name, cb) {
  }
}

export class BeamWindow {
  /**
   * @type string
   */
  origin

  /**
   * @type BeamDocument
   */
  document

  /**
   * @type number
   */
  scrollY

  /**
   * @type number
   */
  scrollX

  /**
   * @type number
   */
  innerWidth

  /**
   * @type number
   */
  innerHeight

  /**
   * @type {BeamVisualViewport}
   */
  visualViewport

  /**
   *
   * @param eventName {String}
   * @param cb {Function}
   */
  addEventListener(eventName, cb) {
  }
}
