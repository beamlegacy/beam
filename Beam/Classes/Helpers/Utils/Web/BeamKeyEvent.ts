import {BeamMouseEvent} from "./BeamMouseEvent"

export class BeamKeyEvent extends BeamMouseEvent {
  constructor(attributes = {}) {
    super()
    Object.assign(this, attributes)
  }

  /**
   * The key name
   *
   * @type String
   */
  key
}
