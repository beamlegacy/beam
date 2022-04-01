import {BeamMutationObserver, BeamMutationRecord, BeamNode, BeamResizeObserver} from "@beam/native-beamtypes"

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

export class BeamResizeObserverMock implements BeamResizeObserver {
  constructor(public fn) {
  }
  observe(): void {
    // throw new Error("Method not implemented.")
  }
  unobserve(): void {
    // throw new Error("Method not implemented.")
  }
  disconnect(): void {
    // throw new Error("Method not implemented.")
  }
}