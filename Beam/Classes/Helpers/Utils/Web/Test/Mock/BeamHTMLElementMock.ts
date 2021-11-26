import {BeamElementMock} from "./BeamElementMock"
import {BeamHTMLElement, BeamNodeType} from "../../BeamTypes"
import {BeamNamedNodeMap} from "../../BeamNamedNodeMap"
import {BeamTextMock} from "./BeamTextMock"

export class BeamHTMLElementMock extends BeamElementMock implements BeamHTMLElement {
  querySelectorResult = {}
  dataset = {
    "beam-mock": "uuid-uuid-uuid-uuid"
  }

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

  setAttribute(qualifiedName: string, value: string): void {
    throw new Error("Method not implemented.")
  }

  getAttribute(qualifiedName: string): string {
    throw new Error("Method not implemented.")
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
