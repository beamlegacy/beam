import {BeamNode, BeamRange, BeamSelection} from "@beam/native-beamtypes"
import {BeamElementMock} from "./BeamElementMock"

export class BeamSelectionMock implements BeamSelection {
  constructor(nodeName: string, attributes = {}) {
    this.anchorNode = new BeamElementMock(nodeName)
    this.focusNode = new BeamElementMock(nodeName)
  }

  anchorNode: BeamNode
  focusNode: BeamNode
  anchorOffset: 0
  focusOffset: 0
  isCollapsed: false
  rangeCount = 0
  type: "Range"
  caretBidiLevel: 0
  private rangelist: BeamRange[] = []

  addRange(range: BeamRange): void {
    this.anchorNode = range.startContainer
    this.focusNode = range.endContainer
    this.rangelist.push(range)
    this.rangeCount++
  }

  collapse(node: BeamNode, offset?: number): void {
    throw new Error("Method not implemented.")
  }

  collapseToEnd(): void {
    throw new Error("Method not implemented.")
  }

  collapseToStart(): void {
    throw new Error("Method not implemented.")
  }

  containsNode(node: BeamNode, allowPartialContainment?: boolean): boolean {
    throw new Error("Method not implemented.")
  }

  deleteFromDocument(): void {
    throw new Error("Method not implemented.")
  }

  empty(): void {
    throw new Error("Method not implemented.")
  }

  extend(node: BeamNode, offset?: number): void {
    throw new Error("Method not implemented.")
  }

  getRangeAt(index: number): BeamRange {
    return this.rangelist[index]
  }

  removeAllRanges(): void {
    throw new Error("Method not implemented.")
  }

  removeRange(range: BeamRange): void {
    throw new Error("Method not implemented.")
  }

  selectAllChildren(node: BeamNode): void {
    throw new Error("Method not implemented.")
  }

  setBaseAndExtent(anchorNode: BeamNode, anchorOffset: number, focusNode: BeamNode, focusOffset: number): void {
    throw new Error("Method not implemented.")
  }

  setPosition(node: BeamNode, offset?: number): void {
    throw new Error("Method not implemented.")
  }

  toString(): string {
    return ""
  }
}
