import {BeamDocument, BeamHTMLElement} from "../BeamTypes"

export class BeamDOMTokenList {
  list = []

  add(...tokens) {
    this.list.push(tokens)
  }
}

export class BeamHTMLElementMock implements BeamHTMLElement {
  classList = new BeamDOMTokenList()
  children = []

  dataset = {}
  clientLeft;
  clientTop;
  height;
  name;
  width;

  constructor(attributes: {} = {}) {
    Object.assign(this, attributes)
  }

  appendChild(el: BeamHTMLElement) {
    this.children.push(el)
  }

  getBoundingClientRect() {
    const x = this.clientLeft
    const y = this.clientTop
    const width = this.width
    const height = this.height
    const top = this.clientTop
    const right = this.clientLeft + this.width
    const bottom = this.clientTop + this.height
    const left = this.clientLeft
    return {x, y, width, height, top, right, bottom, left}
  }

  removeChild(el: BeamHTMLElement) {
    this.children.splice(this.children.indexOf(el), 1)
  }
}

export class BeamHTMLIFrameElementMock extends BeamHTMLElementMock {

  /**
   * @type pns {PointAndShoot}
   */
  pns

  src: string

  constructor(attributes: {} = {}) {
    super({name: "iframe", ...attributes});
  }

  /**
   *
   * @param delta {number} positive or negative scroll delta
   */
  scrollY(delta) {
    this.clientTop += delta
    const win = this.pns.win
    win.scrollY += delta
    const scrollEvent = new BeamUIEvent()
    Object.assign(scrollEvent, {name: "scroll"})
    this.pns.onScroll(scrollEvent)
  }
}


export class BeamDocumentMock implements BeamDocument {
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
