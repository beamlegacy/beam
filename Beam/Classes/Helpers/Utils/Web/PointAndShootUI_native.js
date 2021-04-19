import {PointAndShootUI} from "./PointAndShootUI"

export class PointAndShootUI_native extends PointAndShootUI {
  prefix = "__ID__"

  /**
   * @param win {BeamWindow}
   */
  constructor(win) {
    super()
    console.log(`${this.toString()} instantiated`)
  }

  point(el, _x, _y) {
    this.enterSelection()
  }

  unpoint(el) {
    this.leaveSelection()
  }

  unshoot(el) {
  }

  enterSelection() {

  }

  leaveSelection() {

  }

  /**
   * @param selection {TextSelection}
   * @param className {string}
   */
  paintSelection(selection, className) {

  }

  toString() {
    return this.constructor.name
  }
}
