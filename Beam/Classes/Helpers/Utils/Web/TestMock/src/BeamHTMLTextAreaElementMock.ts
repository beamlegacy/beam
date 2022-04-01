import {BeamHTMLTextAreaElement} from "@beam/native-beamtypes"
import {BeamHTMLElementMock} from "./BeamHTMLElementMock"

export class BeamHTMLTextAreaElementMock extends BeamHTMLElementMock implements BeamHTMLTextAreaElement {
  focus() {
    throw new Error("Method not implemented.")
  }
  srcset?: string
  currentSrc?: string
  src?: string
  id?: string
  value: string
}
