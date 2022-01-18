/*
 * Types used by Beam API (to exchange messages, typically).
 */

import {BeamHTMLCollection} from "./Test/Mock/BeamHTMLCollection"

export class BeamSize {
  constructor(public width: number, public height: number) {}
}

export interface BeamRangeGroup {
  id: string
  range: BeamRange
  text?: string
}

export interface BeamShootGroup {
  id: string
  element: BeamHTMLElement
  text?: string
}

export interface BeamElementBounds {
  element: BeamHTMLElement | BeamElement
  rect: BeamRect
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

  addEventListener(name, cb)
}

export interface BeamResizeInfo {
  width: number
  height: number
}

export interface BeamEmbedContentSize {
  width: number
  height: number
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
  id // Should not be nullable once we get it

  /**
   * @type string
   */
  title
}

export type MessagePayload = Record<string, unknown>

export interface BeamMessageHandler {
  postMessage(message: MessagePayload, targetOrigin?: string, transfer?: Transferable[]): void
}

export type MessageHandlers = {
  [name: string]: BeamMessageHandler
}

export interface BeamWebkit<M = MessageHandlers> {
  /**
   *
   */
  messageHandlers: M
}

export interface BeamCrypto {
  getRandomValues: any
}

export interface BeamWindow<M = MessageHandlers> extends BeamEventTarget {
  matchMedia(arg0: string)
  crypto: BeamCrypto
  frameElement: any
  frames: BeamWindow[]
  /**
   * @type string
   */
  origin

  /**
   * @type BeamDocument
   */
  readonly document: BeamDocument

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

  location: BeamLocation

  webkit: BeamWebkit<M>

  scroll(xCoord: number, yCoord: number): void

  getComputedStyle(el: BeamElement, pseudo?: string): CSSStyleDeclaration

  open(url?: string, name?: string, specs?: string, replace?: boolean): BeamWindow<M> | null
}

export type BeamLocation = Location

export enum BeamNodeType {
  element = 1,
  text = 3,
  processing_instruction = 7,
  comment = 8,
  document = 9,
  document_type = 10,
  document_fragment = 11,
}

export interface BeamEvent {
  readonly type: string
  readonly defaultPrevented: boolean
}

export interface BeamEventTarget<E extends BeamEvent = BeamEvent> {
  addEventListener(type: string, callback: (e: E) => any, options?: any)

  removeEventListener(type: string, callback: (e: E) => any)

  dispatchEvent(e: E)
}

export type BeamDOMRect = DOMRect

export interface BeamNode extends BeamEventTarget {
  offsetHeight: number
  offsetWidth: number
  textContent: string
  nodeName: string
  nodeType: BeamNodeType
  childNodes: BeamNode[]
  parentNode?: BeamNode
  parentElement?: BeamElement

  /**
   * Mock-specific property
   * @deprecated Not because it will be removed, but to warn about non-standard.
   */
  bounds: BeamRect

  /**
   * @param el {HTMLElement}
   */
  appendChild(el: BeamElement): BeamNode

  /**
   * @param el {HTMLElement}
   */
  removeChild(el: BeamHTMLElement)

  contains(el: BeamNode): boolean
}

export interface BeamParentNode extends BeamNode {
  children: BeamHTMLCollection
}

export interface BeamCharacterData extends BeamNode {
  data: string
}

export type BeamText = BeamCharacterData

export interface BeamElement extends BeamParentNode {
  cloneNode(arg0: boolean): BeamElement
  querySelectorAll(query: string): BeamElement[]
  removeAttribute(pointDatasetKey: any)
  dataset: any
  attributes: NamedNodeMap
  srcset?: string
  currentSrc?: string
  src?: string

  /**
   * @type string
   */
  innerHTML: string

  outerHTML: string

  classList: DOMTokenList

  readonly offsetParent: BeamElement

  readonly parentNode?: BeamNode
  readonly parentElement?: BeamElement

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
  href: string
  getClientRects(): DOMRectList
  setAttribute(qualifiedName: string, value: string): void
  getAttribute(qualifiedName: string): string | null

  /**
   * Viewport-relative position.
   */
  getBoundingClientRect(): DOMRect
}

export interface BeamElementCSSInlineStyle {
  style: CSSStyleDeclaration
}

export interface BeamHTMLElement extends BeamElement, BeamElementCSSInlineStyle {
  innerText: string
  nodeValue: any
  dataset: Record<string, string>
}

export interface BeamHTMLInputElement extends BeamHTMLElement {
  type: string
  value: string
}

export interface BeamHTMLTextAreaElement extends BeamHTMLElement {
  value: string
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
  commonAncestorContainer: BeamNode
  cloneContents(): DocumentFragment
  cloneRange(): BeamRange
  collapse(toStart?: boolean): void
  compareBoundaryPoints(how: number, sourceRange: BeamRange): number
  comparePoint(node: BeamNode, offset: number): number
  createContextualFragment(fragment: string): DocumentFragment
  deleteContents(): void
  detach(): void
  extractContents(): DocumentFragment
  getClientRects(): DOMRectList
  insertNode(node: BeamNode): void
  intersectsNode(node: BeamNode): boolean
  isPointInRange(node: BeamNode, offset: number): boolean
  selectNodeContents(node: BeamNode): void
  setEnd(node: BeamNode, offset: number): void
  setEndAfter(node: BeamNode): void
  setEndBefore(node: BeamNode): void
  setStart(node: BeamNode, offset: number): void
  setStartAfter(node: BeamNode): void
  setStartBefore(node: BeamNode): void
  surroundContents(newParent: BeamNode): void
  toString(): string
  END_TO_END: number
  END_TO_START: number
  START_TO_END: number
  START_TO_START: number
  collapsed: boolean
  endContainer: BeamNode
  endOffset: number
  startContainer: BeamNode
  startOffset: number
  selectNode(node: BeamNode): void
  getBoundingClientRect(): DOMRect
}

export declare const BeamRange: {
  prototype: BeamRange
  new (): BeamRange
  readonly END_TO_END: number
  readonly END_TO_START: number
  readonly START_TO_END: number
  readonly START_TO_START: number
  toString(): string
}

export interface BeamDocument extends BeamNode {
  createDocumentFragment(): any
  elementFromPoint(x: any, y: any)
  /**
   * @type {HTMLHtmlElement}
   */
  documentElement

  activeElement: BeamHTMLElement

  /**
   * @type BeamBody
   */
  body: BeamBody

  /**
   * @param tag {string}
   */
  createElement(tag)

  /**
   * @return {BeamSelection}
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

/**
 * {x, y} of mouse location
 *
 * @export
 * @interface BeamMouseLocation
 */
export interface BeamMouseLocation {
  x: number
  y: number
}

export interface BeamSelection {
  anchorNode: BeamNode
  anchorOffset: number
  focusNode: BeamNode
  focusOffset: number
  isCollapsed: boolean
  rangeCount: number
  type: string
  addRange(range: BeamRange): void
  collapse(node: BeamNode, offset?: number): void
  collapseToEnd(): void
  collapseToStart(): void
  containsNode(node: BeamNode, allowPartialContainment?: boolean): boolean
  deleteFromDocument(): void
  empty(): void
  extend(node: BeamNode, offset?: number): void
  getRangeAt(index: number): BeamRange
  removeAllRanges(): void
  removeRange(range: BeamRange): void
  selectAllChildren(node: BeamNode): void
  setBaseAndExtent(anchorNode: BeamNode, anchorOffset: number, focusNode: BeamNode, focusOffset: number): void
  setPosition(node: BeamNode, offset?: number): void
  toString(): string
}

export interface BeamMutationRecord {
  addedNodes: BeamNode[]
  attributeName: string
  attributeNamespace: string
  nextSibling: BeamNode
  oldValue: string
  previousSibling: BeamNode
  removedNodes: BeamNode[]
  target: BeamNode
  type: MutationRecordType
}

export class BeamMutationObserver {
  constructor(public fn) {
    new fn()
  }
  disconnect(): void {
    throw new Error("Method not implemented.")
  }
  observe(_target: BeamNode, _options?: MutationObserverInit): void {
    throw new Error("Method not implemented.")
  }
  takeRecords(): BeamMutationRecord[] {
    throw new Error("Method not implemented.")
  }
}

export interface BeamCoordinates {
  x: number 
  y: number
}

export class FrameInfo {
  /**
   */
  href: string

  /**
   */
  bounds: BeamRect
}

export enum BeamLogLevel {
  log = "log",
  warning = "warning",
  error = "error",
  debug = "debug"
}


export enum BeamLogCategory {
  general = "general",
  pointAndShoot = "pointAndShoot",
  embedNode = "embedNode",
  webpositions = "webpositions",
  navigation = "navigation",
  native = "native"
}