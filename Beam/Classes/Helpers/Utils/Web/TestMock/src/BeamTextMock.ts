import {BeamCharacterDataMock} from "./BeamCharacterDataMock"
import {BeamText} from "@beam/native-beamtypes"

export class BeamTextMock extends BeamCharacterDataMock implements BeamText {
  constructor(data: string, props = {}) {
    super(data, props)
  }
}
