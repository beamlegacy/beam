import {BeamCharacterDataMock} from "./BeamCharacterDataMock"
import {BeamText} from "../../BeamTypes"

export class BeamTextMock extends BeamCharacterDataMock implements BeamText {
  constructor(data: string, props = {}) {
    super(data, props)
  }
}
