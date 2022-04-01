import {BeamDOMRect} from "@beam/native-beamtypes"

export class BeamDOMRectMock implements BeamDOMRect {
  public top: number
  public left: number
  public right: number
  public bottom: number

  constructor(public x: number, public y: number, public width: number, public height: number) {
    this.top = y
    this.left = x
    this.right = x + width
    this.bottom = y + height
  }

  toJSON(): any {
    return JSON.stringify(this)
  }
}
