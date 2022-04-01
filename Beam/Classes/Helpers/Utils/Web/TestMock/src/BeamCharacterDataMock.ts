import {BeamNodeMock} from "./BeamNodeMock"
import {BeamNodeType} from "@beam/native-beamtypes"

export class BeamCharacterDataMock extends BeamNodeMock {
  constructor(readonly data: string, props = {}) {
    super("#text", BeamNodeType.text, props)
  }

  get length(): number {
    return this.data.length
  }

  toString(): string {
    return this.data
  }
}
