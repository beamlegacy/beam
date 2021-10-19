import {BeamHTMLInputElement} from "../../BeamTypes"
import {BeamHTMLElementMock} from "./BeamHTMLElementMock"

export class BeamHTMLInputElementMock extends BeamHTMLElementMock implements BeamHTMLInputElement {
  value: string

  get type(): string {
    const attribute = this.attributes.getNamedItem("type")
    return attribute?.value
  }

  set type(value: string) {
    this.attributes.getNamedItem("type").value = value
  }
}
