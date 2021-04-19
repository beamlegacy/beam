export class BeamDOMTokenList {
  list = []
  add(...tokens) {
    this.list.push(tokens)
  }
}

export class BeamHTMLElement {
  /**
   * @type string
   */
  name

  classList = new BeamDOMTokenList()

  dataset = {}

  /**
   * @type number
   */
  clientTop

  /**
   * @type number
   */
  clientLeft

  /**
   * @type number
   */
  width

  /**
   * @type number
   */
  height

  getBoundingClientRect() {}

  /**
   * @param el {HTMLElement}
   */
  appendChild(el) {
  }

  /**
   * @param el {HTMLElement}
   */
  removeChild(el) {
  }
}

export class BeamBody extends BeamHTMLElement {
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

  constructor(attributes = {}) {
    this.body = {}
    this.documentElement = {}
    Object.assign(this, attributes)
  }

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

export class BeamMessageHandler {
  postMessage(payload) {
  }
}

export class BeamWebkit {
  /**
   *
   */
  messageHandlers = {}
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

  location

  /**
   * @type BeamWebkit
   */
  webkit = new BeamWebkit()

  eventListeners

  /**
   *
   * @param eventName {String}
   * @param cb {Function}
   */
  addEventListener(eventName, cb) {
  }
}

/**
 * We need this for tests as some properties of UIEvent (target) are readonly.
 */
export class BeamUIEvent {
  /**
   * @type BeamHTMLElement
   */
  target

  preventDefault() {
  }

  stopPropagation() {
  }
}

export class BeamMouseEvent extends BeamUIEvent {

  constructor(attributes = {}) {
    super()
    Object.assign(this, attributes)
  }

  /**
   * If the Option key was down during the event.
   *
   * @type boolean
   */
  altKey

  /**
   * @type number
   */
  clientX

  /**
   * @type number
   */
  clientY
}

export class BeamKeyEvent extends BeamUIEvent {

  constructor(attributes = {}) {
    super()
    Object.assign(this, attributes)
  }

  /**
   * The key name
   *
   * @type String
   */
  key
}
