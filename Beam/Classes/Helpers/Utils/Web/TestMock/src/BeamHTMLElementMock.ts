import {BeamHTMLElement, BeamNodeType, BeamNamedNodeMap} from "@beam/native-beamtypes"
import {BeamElementMock} from "./BeamElementMock"
import {BeamTextMock} from "./BeamTextMock"

export class BeamHTMLElementMock extends BeamElementMock implements BeamHTMLElement {
  querySelectorResult = {}
  dataset = {
    "beam-mock": "uuid-uuid-uuid-uuid"
  }
  isConnected: boolean

  constructor(nodeName: string, attributes = {}) {
    super(nodeName, new BeamNamedNodeMap(attributes))
  }
  parentElement?: BeamHTMLElement

  setQuerySelectorResult(query: string, element: BeamHTMLElementMock) {
    // if no array exists yet, create one
    if (!this.querySelectorResult[query]) {
      this.querySelectorResult[query] = []
    }
    this.querySelectorResult[query].push(element)
  }

  querySelectorAll(query: string): BeamHTMLElementMock[] {
    if (query == "*") {
      const arrays = Object.values(this.querySelectorResult) || []
      return [].concat(...arrays)
    }

    return this.querySelectorResult[query] || []
  }

  querySelector(query: string): BeamHTMLElementMock {
    if (query == "*") {
      const arrays = Object.values(this.querySelectorResult) || []
      return [].concat(...arrays).pop()
    }

    return this.querySelectorResult[query].pop()
  }
  removeAttribute(pointDatasetKey: any) {
    delete this.attributes[pointDatasetKey]
  }

  setAttribute(qualifiedName: string, value: string) {
    const attr = document.createAttribute(qualifiedName)
    attr.value = value
    this.attributes.setNamedItem(attr)
  }

  getAttribute(qualifiedName: string): string {
    const item = this.attributes.getNamedItem(qualifiedName)
    return item?.value
  }

  nodeValue: any

  get innerText(): string {
    return this.textContent
  }

  set innerText(text: string) {
    const textNodes = this.childNodes.filter((node) => node.nodeType === BeamNodeType.text)
    for (const textNode of textNodes) {
      this.removeChild(textNode)
    }
    this.appendChild(new BeamTextMock(text))
  }
}
