/*
 * Types used by Beam API (to exchange messages, typically).
 */

import {BeamDOMTokenList} from "./Test/BeamMocks"

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

export interface BeamVisualViewport {
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

  addEventListener(name, cb)
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

export class NoteInfo {
  /**
   * @type string
   */
  id   // Should not be nullable once we get it

  /**
   * @type string
   */
  title
}

export interface BeamMessageHandler {
  postMessage(payload: any)
}

export interface BeamWebkit {
  /**
   *
   */
  messageHandlers: {}
}

export interface BeamWindow {
  /**
   * @type string
   */
  origin

  /**
   * @type BeamDocument
   */
  readonly document: BeamDocument;

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
  webkit

  eventListeners

  /**
   *
   * @param eventName {String}
   * @param cb {Function}
   */
  addEventListener(eventName: string, cb: Function)
}

export interface BeamHTMLElement {
  /**
   * @type string
   */
  name: string

  children: BeamHTMLElement[]

  classList: BeamDOMTokenList

  dataset: {}

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

  getBoundingClientRect()

  /**
   * @param el {HTMLElement}
   */
  appendChild(el: BeamHTMLElement)

  /**
   * @param el {HTMLElement}
   */
  removeChild(el: BeamHTMLElement)
}
export interface BeamBody extends BeamHTMLElement {
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

export interface BeamDocument {
  /**
   * @type {HTMLHtmlElement}
   */
  documentElement

  /**
   * @type BeamBody
   */
  body: BeamBody

  /**
   * @param tag {string}
   */
  createElement(tag)

  /**
   *
   * @param eventName {String}
   * @param cb {Function}
   */
  addEventListener(eventName, cb)

  /**
   * @return {Selection}
   */
  getSelection()

  /**
   * @param selector {string}
   * @return {HTMLElement[]}
   */
  querySelectorAll(selector)
}
