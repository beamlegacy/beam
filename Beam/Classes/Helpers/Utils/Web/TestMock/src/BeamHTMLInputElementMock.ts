import {BeamHTMLInputElement} from "@beam/native-beamtypes"
import {BeamHTMLElementMock} from "./BeamHTMLElementMock"

export class BeamHTMLInputElementMock extends BeamHTMLElementMock implements BeamHTMLInputElement {
  focus() {
    throw new Error("Method not implemented.")
  }
  srcset?: string
  currentSrc?: string
  src?: string
  id?: string
  value: string

  get type(): string {
    const attribute = this.attributes.getNamedItem("type")
    return attribute?.value
  }

  set type(value: string) {
    this.attributes.getNamedItem("type").value = value
  }
}
