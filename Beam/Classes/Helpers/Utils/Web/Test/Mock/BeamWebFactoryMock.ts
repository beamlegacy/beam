import {BeamMutationObserver, BeamMutationRecord, BeamNode} from "../../BeamTypes"

export class BeamMutationObserverMock implements BeamMutationObserver {
  constructor(public fn) {
    console.log("BeamMutationObserverMock init")
  }
  private targets: BeamNode[] = []
  disconnect(): void {
    this.targets = []
  }
  observe(target: BeamNode, options?: MutationObserverInit): void {
    this.targets.push(target)
  }
  takeRecords(): BeamMutationRecord[] {
    throw new Error("Method not implemented.")
  }
}