import {BeamEventTargetMock} from "./BeamEventTargetMock"
import {BeamElement, BeamNode, BeamNodeType, BeamRect} from "../../BeamTypes"
import {BeamElementMock} from "./BeamElementMock"

export class BeamNodeMock extends BeamEventTargetMock implements BeamNode {
  static readonly ELEMENT_NODE = BeamNodeType.element
  static readonly TEXT_NODE = BeamNodeType.text
  static readonly PROCESSING_INSTRUCTION_NODE = BeamNodeType.processing_instruction
  static readonly COMMENT_NODE = BeamNodeType.comment
  static readonly DOCUMENT_NODE = BeamNodeType.document
  static readonly DOCUMENT_TYPE_NODE = BeamNodeType.document_type
  static readonly DOCUMENT_FRAGMENT_NODE = BeamNodeType.document_fragment

  childNodes: BeamNode[] = []
  parentNode?: BeamNode
  parentElement?: BeamElement
  isConnected: boolean = true

  /**
   * @deprecated Not standard, for test purpose
   * Relative bounds
   */
  bounds = new BeamRect(0, 0, 0, 0)

  constructor(readonly nodeName: string, readonly nodeType: BeamNodeType, props = {}) {
    super()
    Object.assign(this, props)
    this.nodeName = nodeName
    this.nodeType = nodeType
  }
  offsetHeight: number
  offsetWidth: number

  appendChild(node: BeamNode): BeamNode {
    this.childNodes.push(node)
    node.parentNode = this
    if (this instanceof BeamElementMock) {
      node.parentElement = this as unknown as BeamElement
    }
    return node
  }

  removeChild(el: BeamNode) {
    this.childNodes = this.childNodes.splice(this.childNodes.indexOf(el), 1)
    el.parentNode = null
    el.parentElement = null
  }

  contains(el: BeamNode): boolean {
    return this === el || this.childNodes.some((childNode) => childNode === el || childNode.contains(el))
  }

  get textContent(): string {
    const collectTextNodes = (node: BeamNode): string => {
      const text = node.childNodes.reduce((acc: string[], node) => {
        if (node.nodeType === BeamNodeType.text) {
          acc.push(`${node}`)
        } else if (node.nodeType === BeamNodeType.element) {
          acc.push(...collectTextNodes(node))
        }
        return acc
      }, [])
      return text.join("")
    }
    return collectTextNodes(this)
  }
}
