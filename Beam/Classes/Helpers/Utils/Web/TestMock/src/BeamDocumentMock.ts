import {
  BeamDocument,
  BeamHTMLElement,
  BeamNode,
  BeamNodeType,
  BeamRange,
  BeamSelection
} from "@beam/native-beamtypes"
import { BeamSelectionMock } from "./BeamSelectionMock"
import { BeamNodeMock } from "./BeamNodeMock"
import { BeamElementMock } from "./BeamElementMock"
import { BeamRangeMock } from "./BeamRangeMock"
import { BeamHTMLElementMock } from "./BeamHTMLElementMock"

export const BeamDocumentMockDefaults = {
  body: {
    styleData: {
      style: {
        zoom: "1"
      }
    },
    scrollData: {
      scrollWidth: 800,
      scrollHeight: 0,
      offsetWidth: 800,
      offsetHeight: 0,
      clientWidth: 800,
      clientHeight: 0
    }
  },
  documentElement: {
    scrollWidth: 800,
    scrollHeight: 0,
    offsetWidth: 800,
    offsetHeight: 0,
    clientWidth: 800,
    clientHeight: 0
  }
}

export class BeamTreeWalker implements TreeWalker {
  currentNode: Node
  filter: NodeFilter
  root: Node
  whatToShow: number
  constructor(root, whatToShow, filter ) {
    this.root = root
    this.currentNode = root
    this.whatToShow = whatToShow
    this.filter = filter
  }
  firstChild(): Node {
    return this.currentNode.firstChild
  }
  lastChild(): Node {
    return this.currentNode.lastChild
  }
  nextNode(): Node {
    return this.currentNode.nextSibling
  }
  nextSibling(): Node {
    return this.currentNode.nextSibling
  }
  parentNode(): Node {
    return this.currentNode.parentNode
  }
  previousNode(): Node {
    return this.currentNode.previousSibling
  }
  previousSibling(): Node {
    return this.currentNode.previousSibling
  }

}

export class BeamDocumentMock extends BeamNodeMock implements BeamDocument {
  /**
   * @type {HTMLHtmlElement}
   */
  documentElement: BeamHTMLElement = new BeamHTMLElementMock("div", {})

  activeElement: BeamHTMLElement

  /**
   * @type BeamBody
   */
  body

  private selection: BeamSelection

  constructor(attributes = {}) {
    super("#document", BeamNodeType.document)
    this.body = {}
    this.selection = new BeamSelectionMock("div")
    this.childNodes = [new BeamNodeMock("#text", 3)]
    Object.assign(this, attributes)
  }
  createTreeWalker(root: BeamNode, whatToShow?: number, filter?: NodeFilter, _expandEntityReferences?: boolean): TreeWalker {
    return new BeamTreeWalker(root, whatToShow, filter)
  }
  createTextNode(data: string): Text {
    throw new Error("Method not implemented.")
  }
  muted?: boolean
  paused?: boolean
  webkitSetPresentationMode(BeamWebkitPresentationMode: any) {
    throw new Error("Method not implemented.")
  }

  createDocumentFragment() {
    throw new Error("Method not implemented.")
  }

  elementFromPoint(x: any, y: any) {
    return this.documentElement
  }

  /**
   * @param tag {string}
   */
  createElement(tag) {
    return new BeamElementMock(tag)
  }

  /**
   *
   * @param eventName {String}
   * @param cb {Function}
   */
  addEventListener(eventName, cb) {
    // TODO: Shouldn't we implement it?
  }

  /**
   * @return {BeamSelection}
   */
  getSelection() {
    return this.selection
  }

  /**
   * @param selector {string}
   * @return {HTMLElement[]}
   */
  querySelectorAll(selector): BeamNode[] {
    return [] // Override it in your custom mock
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
