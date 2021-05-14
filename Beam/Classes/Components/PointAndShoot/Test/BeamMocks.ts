import {
  BeamDocument,
  BeamDOMRect,
  BeamElement,
  BeamElementCSSInlineStyle,
  BeamHTMLElement,
  BeamHTMLIFrameElement,
  BeamNode,
  BeamNodeType,
  BeamRange,
  BeamRect,
  BeamText,
  BeamWindow
} from "../BeamTypes"
import {BeamWindowMock} from "./BeamWindowMock"
import {BeamEventTargetMock} from "./BeamEventTargetMock"
import {Util} from "../Util"

export class BeamDOMTokenList {
  list = []

  add(...tokens) {
    this.list.push(tokens)
  }
}

export class BeamNodeMock extends BeamEventTargetMock implements BeamNode {

  static readonly ELEMENT_NODE = BeamNodeType.element
  static readonly TEXT_NODE = BeamNodeType.text
  static readonly PROCESSING_INSTRUCTION_NODE = BeamNodeType.processing_instruction
  static readonly COMMENT_NODE = BeamNodeType.comment
  static readonly DOCUMENT_NODE = BeamNodeType.document
  static readonly DOCUMENT_TYPE_NODE = BeamNodeType.document_type
  static readonly DOCUMENT_FRAGMENT_NODE = BeamNodeType.document_fragment

  innerText: string

  childNodes: BeamNode[] = []
  parentNode?: BeamNode

  /**
   * @deprecated Not standard, for test purpose
   * Relative bounds
   */
  bounds = new BeamRect()

  constructor(readonly nodeName: string, readonly nodeType: BeamNodeType, props = {}) {
    super()
    Object.assign(this, props)
    this.nodeName = nodeName
    this.nodeType = nodeType
  }

  appendChild(node: BeamNode): BeamNode {
    this.childNodes.push(node)
    node.parentNode = this
    return node
  }

  removeChild(el: BeamNode) {
    this.childNodes = this.childNodes.splice(this.childNodes.indexOf(el), 1)
    el.parentNode = null
  }
}

export class BeamCharacterDataMock extends BeamNodeMock {

  constructor(readonly data: string, props = {}) {
    super("#text", BeamNodeType.text, props)
  }

  get length(): number {
    return this.data.length
  }

  toString(): string {
    return this.data
  }
}

export class BeamTextMock extends BeamCharacterDataMock implements BeamText {

  constructor(data: string, props = {}) {
    super(data, props)
  }
}

export class BeamNamedNodeMap extends Object implements NamedNodeMap {
  [index: number]: Attr

  private readonly attrs: Attr[] = []

  constructor(props = {}) {
    super()
    for (const p in props) {
      if (props.hasOwnProperty(p)) {
        const attr: Attr = {
          ATTRIBUTE_NODE: 0,
          CDATA_SECTION_NODE: 0,
          COMMENT_NODE: 0,
          DOCUMENT_FRAGMENT_NODE: 0,
          DOCUMENT_NODE: 0,
          DOCUMENT_POSITION_CONTAINED_BY: 0,
          DOCUMENT_POSITION_CONTAINS: 0,
          DOCUMENT_POSITION_DISCONNECTED: 0,
          DOCUMENT_POSITION_FOLLOWING: 0,
          DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC: 0,
          DOCUMENT_POSITION_PRECEDING: 0,
          DOCUMENT_TYPE_NODE: 0,
          ELEMENT_NODE: 0,
          ENTITY_NODE: 0,
          ENTITY_REFERENCE_NODE: 0,
          NOTATION_NODE: 0,
          PROCESSING_INSTRUCTION_NODE: 0,
          TEXT_NODE: 0,
          addEventListener(type: string, listener: EventListenerOrEventListenerObject | null, options: boolean | AddEventListenerOptions | undefined): void {
          },
          appendChild<T>(newChild: T): T {
            return undefined
          },
          baseURI: "",
          childNodes: undefined,
          cloneNode(deep: boolean | undefined): Node {
            return undefined
          },
          compareDocumentPosition(other: Node): number {
            return 0
          },
          contains(other: Node | null): boolean {
            return false
          },
          dispatchEvent(event: Event): boolean {
            return false
          },
          firstChild: undefined,
          getRootNode(options: GetRootNodeOptions | undefined): Node {
            return undefined
          },
          hasChildNodes(): boolean {
            return false
          },
          insertBefore<T>(newChild: T, refChild: Node | null): T {
            return undefined
          },
          isConnected: false,
          isDefaultNamespace(namespace: string | null): boolean {
            return false
          },
          isEqualNode(otherNode: Node | null): boolean {
            return false
          },
          isSameNode(otherNode: Node | null): boolean {
            return false
          },
          lastChild: undefined,
          lookupNamespaceURI(prefix: string | null): string | null {
            return undefined
          },
          lookupPrefix(namespace: string | null): string | null {
            return undefined
          },
          namespaceURI: undefined,
          nextSibling: undefined,
          nodeName: "",
          nodeType: 0,
          nodeValue: undefined,
          ownerDocument: undefined,
          ownerElement: undefined,
          parentElement: undefined,
          parentNode: undefined,
          prefix: undefined,
          previousSibling: undefined,
          removeChild<T>(oldChild: T): T {
            return undefined
          },
          removeEventListener(type: string, callback: EventListenerOrEventListenerObject | null, options: EventListenerOptions | boolean | undefined): void {
          },
          replaceChild<T>(newChild: Node, oldChild: T): T {
            return undefined
          },
          specified: false,
          textContent: undefined,
          normalize(): void {
          },
          name: p,
          localName: p,
          value: props[p]
        }
        this.setNamedItem(attr)
      }
    }
  }

  get length(): number {
    return this.attrs.length
  }

  getNamedItem(qualifiedName: string): Attr | null {
    return this.attrs.find(a => a.localName === qualifiedName)
  }

  getNamedItemNS(namespace: string | null, localName: string): Attr | null {
    return this.getNamedItem(`${namespace}.${localName}`)
  }

  item(index: number): Attr | null {
    return this.attrs[index]
  }

  removeNamedItem(qualifiedName: string): Attr {
    const old = this.getNamedItem(qualifiedName)
    const index = this.attrs.indexOf(old)
    this.attrs.splice(index, 1)
    return old
  }

  removeNamedItemNS(namespace: string | null, localName: string): Attr {
    return this.removeNamedItem(namespace + "." + localName)
  }

  setNamedItem(attr: Attr): Attr | null {
    const old = this.getNamedItem(attr.localName)
    if (old) {
      this.removeNamedItem(attr.localName)
    }
    this.attrs.push(attr)
    return old
  }

  setNamedItemNS(attr: Attr): Attr | null {
    return undefined
  }

  [Symbol.iterator](): IterableIterator<Attr> {
    return this.attrs.values()
  }

  toString(): string {
    return this.attrs.map(a => `${a.name}="${a.value}"`).join(" ")
  }
}

export class BeamHTMLCollection<E extends BeamElement = BeamElement> /*implements HTMLCollection*/ {
  constructor(private values: E[]) {
  }

  [index: number]: E

  get length(): number {
    return this.values.length
  }

  [Symbol.iterator](): IterableIterator<E> {
    return this.values.values()
  }

  item(index: number): E | null {
    return this.values[index]
  }

  namedItem(name: string): E | null {
    return this.item(parseInt(name, 10))
  }
}

export class BeamDOMRectList implements DOMRectList {
  constructor(private list: DOMRect[]) {
  }

  [index: number]: DOMRect

  get length(): number {
    return this.list.length
  }

  [Symbol.iterator](): IterableIterator<DOMRect> {
    return this.list.values()
  }

  item(index: number): DOMRect | null {
    return this.list[index]
  }
}

export class BeamDOMRectMock implements BeamDOMRect {
  public top: number
  public left: number
  public right: number
  public bottom: number

  constructor(public x: number, public y: number, public width: number, public height: number) {
    this.top = y
    this.left = x
    this.right = x + width
    this.bottom = y + height
  }

  toJSON(): any {
    return JSON.stringify(this)
  }
}

export class BeamElementMock extends BeamNodeMock implements BeamElement, BeamElementCSSInlineStyle {
  style: CSSStyleDeclaration
  attributes: NamedNodeMap
  classList: DOMTokenList
  clientLeft: number = 0
  clientTop: number = 0
  offsetLeft: number = 0
  offsetTop: number = 0
  offsetParent: BeamElement
  scrollLeft: number = 0
  scrollTop: number = 0

  scrollHeight: number
  scrollWidth: number

  _height: number = 0
  _width: number = 0

  constructor(readonly tagName: string, attributes: NamedNodeMap = new BeamNamedNodeMap(), props = {}) {
    super(tagName, BeamNodeType.element)
    this.attributes = attributes
  }
  dataset: any

  set width(value: number) {
    this._width = value
    this.scrollWidth = value
  }

  get width(): number {
    return this._width
  }

  get height(): number {
    return this._height
  }

  set height(value: number) {
    this._height = value
    this.scrollHeight = value
  }

  get parentNode(): BeamElement {
    const p = super.parentNode
    const pe = p ? p : null
    return pe as BeamElement
  }

  appendChild(node: BeamNode): BeamNode {
    const added = super.appendChild(node)
    if (node instanceof BeamElementMock) {
      (node as BeamElementMock).offsetParent = this
    }
    return added
  }

  private get _children(): BeamElement[] {
    return this.childNodes.filter(e => e.nodeType === BeamNodeMock.ELEMENT_NODE) as BeamElement[]
  }

  get children(): BeamHTMLCollection {
    const beamNodes = this._children
    return new BeamHTMLCollection(beamNodes)
  }

  get innerHTML(): string {
    return this.childNodes.map(c => c.toString()).join("")
  }

  get outerHTML(): string {
    const tag = this.nodeName
    let attributes = ""
    for (const a of this.attributes) {
      attributes += ` ${a.name}="${a.value}"`
    }
    return `<${tag}${attributes}>${this.innerHTML}</${tag}>`
  }

  toString() {
    return this.outerHTML
  }

  getBoundingClientRect(): DOMRect {
    const xy = Util.getTopLeft(this)
    return new BeamDOMRectMock(xy.x, xy.y, this.width, this.height)
  }

  getClientRects(): DOMRectList {
    const list = this._children.map(c => c.getBoundingClientRect())
    return new BeamDOMRectList(list)
  }
}

export class BeamHTMLElementMock extends BeamElementMock implements BeamHTMLElement {

  dataset = {
    "beam-mock": "uuid-uuid-uuid-uuid"
  }

  constructor(nodeName: string, attributes = {}) {
    super(nodeName, new BeamNamedNodeMap(attributes))
  }
  nodeValue: any
}

export class BeamHTMLIFrameElementMock extends BeamHTMLElementMock implements BeamHTMLIFrameElement {

  src: string

  contentWindow: BeamWindow = new BeamWindowMock()

  constructor(attributes: NamedNodeMap = new BeamNamedNodeMap()) {
    super("iframe", attributes)
  }
  nodeValue: any

  /**
   *
   * @param delta {number} positive or negative scroll delta
   */
  scrollY(delta: number) {
    this.clientTop += delta
    const win = this.contentWindow as BeamWindowMock
    win.scroll(0, win.scrollY + delta)
    const scrollEvent = new BeamUIEvent()
    Object.assign(scrollEvent, {name: "scroll"})
    win.pns.onScroll(scrollEvent)
  }
}


export class BeamRangeMock implements BeamRange {
  private node: BeamNode

  getBoundingClientRect(): BeamRect {
    return this.node.bounds
  }

  selectNode(node: BeamNode): void {
    this.node = node
  }
}

export class BeamDocumentMock extends BeamNodeMock implements BeamDocument {
  /**
   * @type {HTMLHtmlElement}
   */
  documentElement

  /**
   * @type BeamBody
   */
  body

  constructor(attributes = {}) {
    super("#document", BeamNodeType.document)
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
      return {
        toString: () => {
          return ""
      }
    }
  }

  /**
   * @param selector {string}
   * @return {HTMLElement[]}
   */
  querySelectorAll(selector): BeamNode[] {
    return []   // Override it in your custom mock
  }

  createRange(): BeamRange {
    return new BeamRangeMock()
  }

  /**
   * @param selector {string}
   * @return {HTMLElement[]}
   */
  querySelector(selector): BeamNode {
    return
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
