import {BeamNodeMock} from "./BeamNodeMock"
import {BeamElement, BeamElementCSSInlineStyle, BeamNode, BeamNodeType, BeamNamedNodeMap, BeamHTMLCollection, BeamDOMRectList} from "@beam/native-beamtypes"
import {PointAndShootHelper} from "@beam/native-utils"
import {BeamDOMRectMock} from "./BeamDOMRectMock"

export class BeamElementMock extends BeamNodeMock implements BeamElement, BeamElementCSSInlineStyle {
  style: CSSStyleDeclaration
  attributes: NamedNodeMap
  classList: DOMTokenList
  clientLeft = 0
  clientTop = 0
  offsetLeft = 0
  offsetTop = 0
  offsetParent: BeamElement
  scrollLeft = 0
  scrollTop = 0
  href: string
  scrollHeight: number
  scrollWidth: number
  focus() {
    // todo
  }

  _height = 0
  _width = 0
  querySelectorResult = {}

  constructor(readonly tagName: string, attributes: NamedNodeMap = new BeamNamedNodeMap(), props = {}) {
    super(tagName, BeamNodeType.element)
    this.attributes = attributes
  }

  setQuerySelectorResult(query: string, element: BeamElementMock) {
    // if no array exists yet, create one
    if (!this.querySelectorResult[query]) {
      this.querySelectorResult[query] = []
    }
    this.querySelectorResult[query].push(element)
  }
  cloneNode(): BeamElement {
    return Object.assign({}, this)
  }
  querySelectorAll(query: string): BeamElementMock[] {
    if (query == "*") {
      const arrays = Object.values(this.querySelectorResult) || []
      return [].concat(...arrays)
    }

    return this.querySelectorResult[query] || []
  }

  removeAttribute(pointDatasetKey: any) {
    delete this.attributes[pointDatasetKey]
  }

  setAttribute(qualifiedName: string, value: string): void {
    const attr = document.createAttribute(qualifiedName)
    attr.value = value
    this.attributes.setNamedItem(attr)
  }

  getAttribute(qualifiedName: string): string {
    const item = this.attributes.getNamedItem(qualifiedName)
    return item?.value
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

  appendChild(node: BeamNode): BeamNode {
    const added = super.appendChild(node)
    if (node instanceof BeamElementMock) {
      (node as BeamElementMock).offsetParent = this
    }
    return added
  }

  private get _children(): BeamElement[] {
    return this.childNodes.filter((e) => e.nodeType === BeamNodeMock.ELEMENT_NODE) as BeamElement[]
  }

  get children(): BeamHTMLCollection {
    const beamNodes = this._children
    return new BeamHTMLCollection(beamNodes)
  }

  get innerHTML(): string {
    return this.childNodes.map((c) => c.toString()).join("")
  }

  get outerHTML(): string {
    const tag = this.nodeName
    let attributes = ""
    for (const a of Array.from(this.attributes)) {
      attributes += ` ${a.name}="${a.value}"`
    }
    return `<${tag}${attributes}>${this.innerHTML}</${tag}>`
  }

  toString() {
    return this.outerHTML
  }

  getBoundingClientRect(): DOMRect {
    const xy = PointAndShootHelper.getTopLeft(this)
    return new BeamDOMRectMock(xy.x, xy.y, this.width, this.height)
  }

  getClientRects(): DOMRectList {
    const list = this._children.map((c) => c.getBoundingClientRect())
    return new BeamDOMRectList(list)
  }
}
