import {BeamNode, BeamRange, BeamDOMRectList} from "@beam/native-beamtypes"
import {BeamDOMRectMock} from "./BeamDOMRectMock"

export class BeamRangeMock implements BeamRange {
  cloneRange(): BeamRange {
    throw new Error("Method not implemented.")
  }

  collapse(toStart?: boolean): void {
    throw new Error("Method not implemented.")
  }

  compareBoundaryPoints(how: number, sourceRange: BeamRange): number {
    throw new Error("Method not implemented.")
  }

  comparePoint(node: BeamNode, offset: number): number {
    throw new Error("Method not implemented.")
  }

  createContextualFragment(fragment: string): DocumentFragment {
    throw new Error("Method not implemented.")
  }

  deleteContents(): void {
    throw new Error("Method not implemented.")
  }

  detach(): void {
    throw new Error("Method not implemented.")
  }

  extractContents(): DocumentFragment {
    throw new Error("Method not implemented.")
  }

  getClientRects(): BeamDOMRectList {
    const rect = new BeamDOMRectMock(0, 0, 0, 0)
    return new BeamDOMRectList([rect])
  }

  insertNode(node: BeamNode): void {
    throw new Error("Method not implemented.")
  }

  intersectsNode(node: BeamNode): boolean {
    throw new Error("Method not implemented.")
  }

  isPointInRange(node: BeamNode, offset: number): boolean {
    throw new Error("Method not implemented.")
  }

  selectNodeContents(node: BeamNode): void {
    throw new Error("Method not implemented.")
  }

  setEnd(node: BeamNode, offset: number): void {
    this.endOffset = offset
    this.endContainer = node
  }

  setEndAfter(node: BeamNode): void {
    throw new Error("Method not implemented.")
  }

  setEndBefore(node: BeamNode): void {
    throw new Error("Method not implemented.")
  }

  setStart(node: BeamNode, offset: number): void {
    this.startOffset = offset
    this.startContainer = node
  }

  setStartAfter(node: BeamNode): void {
    throw new Error("Method not implemented.")
  }

  setStartBefore(node: BeamNode): void {
    throw new Error("Method not implemented.")
  }

  surroundContents(newParent: BeamNode): void {
    throw new Error("Method not implemented.")
  }

  toString(): string {
    return "mock range content"
  }

  END_TO_END: number
  END_TO_START: number
  START_TO_END: number
  START_TO_START: number
  collapsed: boolean
  endContainer: BeamNode
  endOffset: number
  startContainer: BeamNode
  startOffset: number
  commonAncestorContainer: BeamNode

  cloneContents(): DocumentFragment {
    return this.startContainer as any
  }

  private node: BeamNode

  getBoundingClientRect(): DOMRect {
    return {
      ...this.node.bounds,
      bottom: 0,
      left: 0,
      right: 0,
      top: 0,
      toJSON: () => "toJSON value not implemented"
    }
  }

  selectNode(node: BeamNode): void {
    this.node = node
    const parentBox = node.parentElement.getBoundingClientRect()
    this.node.bounds.x = this.node.bounds.x || parentBox.x
    this.node.bounds.y = this.node.bounds.y || parentBox.y
    this.node.bounds.width = this.node.bounds.width || parentBox.width
    this.node.bounds.height = this.node.bounds.height || parentBox.height
  }
}
