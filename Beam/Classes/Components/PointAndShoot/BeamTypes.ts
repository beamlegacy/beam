/*
 * Types used by Beam API (to exchange messages, typically).
 */

import {BeamHTMLCollection} from "./Test/BeamMocks"

export class BeamSize {

  constructor(public width: number, public height: number) {
  }
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

  constructor(public x: number, public y: number, width: number, height: number) {
    super(width, height)
  }
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

export interface BeamWindow extends BeamEventTarget {
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

  scroll(xCoord: number, yCoord: number): void
}

export enum BeamNodeType {
  element = 1,
  text = 3,
  processing_instruction = 7,
  comment = 8,
  document = 9,
  document_type = 10,
  document_fragment = 11
}

export interface BeamEvent {
  readonly type: string
  readonly defaultPrevented: boolean
}

export interface BeamEventTarget<E extends BeamEvent = BeamEvent> {

  addEventListener(type: string, callback: (e: E) => any)

  removeEventListener(type: string, callback: (e: E) => any)

  dispatchEvent(e: E)
}

export interface BeamDOMRect extends DOMRect {
}

export interface BeamNode extends BeamEventTarget {
  innerText: string
  nodeName: string
  nodeType: BeamNodeType
  childNodes: BeamNode[]
  parentNode?: BeamNode

  /**
   * Mock-specific property
   * @deprecated Not because it will be removed, but to warn about non-standard.
   */
  bounds: BeamRect

  /**
   * @param el {HTMLElement}
   */
  appendChild(el: BeamHTMLElement): BeamNode

  /**
   * @param el {HTMLElement}
   */
  removeChild(el: BeamHTMLElement)
}

export interface BeamParentNode extends BeamNode {
  children: BeamHTMLCollection
}

export interface BeamCharacterData extends BeamNode {
  data: string
}

export interface BeamText extends BeamCharacterData {
}

export interface BeamElement extends BeamParentNode {
  dataset: any
  attributes: {}

  /**
   * @type string
   */
  innerHTML: string

  outerHTML: string

  classList: DOMTokenList

  readonly offsetParent: BeamElement

  readonly parentNode?: BeamElement

  /**
   * Parent padding-relative x coordinate.
   */
  offsetLeft: number

  /**
   * Parent padding-relative y coordinate.
   */
  offsetTop: number

  /**
   * Left border width
   */
  clientLeft: number

  /**
   * Top border width
   */
  clientTop: number
  height: number
  width: number
  scrollLeft: number
  scrollTop: number
  scrollHeight: number
  scrollWidth: number
  tagName: string

  getClientRects(): DOMRectList

  /**
   * Viewport-relative position.
   */
  getBoundingClientRect(): DOMRect
}

export interface BeamElementCSSInlineStyle {
  style: CSSStyleDeclaration
}

export interface BeamHTMLElement extends BeamElement, BeamElementCSSInlineStyle {
  nodeValue: any

  dataset: {}
}

export interface BeamHTMLIFrameElement extends BeamHTMLElement {

  src: string
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

export interface BeamRange {
  
  selectNode(node: BeamNode): void
  
  getBoundingClientRect(): BeamRect
}

export interface BeamDocument extends BeamNode {
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
   * @return {Selection}
   */
  getSelection()

  /**
   * @param selector {string}
   * @return {HTMLElement[]}
   */
  querySelectorAll(selector: string): BeamNode[]

  /**
   * @param selector {string}
   * @return {HTMLElement}
   */
  querySelector(selector: string): BeamNode

  createRange(): BeamRange
}

export enum BeamPNSStatus {
  pointing = "pointing",
  shooting = "shooting",
  none = "none"
}
