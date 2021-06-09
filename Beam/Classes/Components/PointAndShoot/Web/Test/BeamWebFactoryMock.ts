import { BeamMutationObserver, BeamMutationRecord, BeamNode } from "../BeamTypes";
import { WebFactory } from "../WebFactory";

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
    throw new Error("Method not implemented.");
  }
}

export class BeamWebFactoryMock implements WebFactory {
  MutationObserver: BeamMutationObserver;
  createMutationObserver(fn): BeamMutationObserver {
    return new BeamMutationObserverMock(fn)
  }
}