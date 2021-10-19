import {BeamUIEvent} from "./BeamUIEvent"

export class BeamMouseEvent extends BeamUIEvent {
  constructor(attributes = {}) {
    super()
    Object.assign(this, attributes)
  }

  /**
   * If the Option key was down during the event.
   *
   * @type boolean
   */
  altKey

  /**
   * @type number
   */
  clientX

  /**
   * @type number
   */
  clientY
}
