import {TextSelectorUI} from "./TextSelectorUI"

export class TextSelectorUI_web extends TextSelectorUI {
  prefix = "__ID__"

  textPointClass = `${this.prefix}-point`

  textShootClass = `${this.prefix}-shoot`

  /**
   * @type {(BeamWindow)}
   */
  win

  /**
   * @param win {BeamWindow}
   * @param pointAndShoot {PointAndShootUI_web}
   */
  constructor(win, pointAndShoot) {
    super()
    this.win = win
    this.pointAndShoot = pointAndShoot
    console.log(`${this} instantiated`)
  }

  enterSelection() {
    this.pointAndShoot.enterSelection()
  }

  leaveSelection() {
    this.pointAndShoot.leaveSelection()
  }

  addTextSelection(selection) {
    this.pointAndShoot.paintSelection(selection, this.textPointClass)
  }

  textSelected(selection) {
    this.pointAndShoot.paintSelection(selection, this.textShootClass)
  }

  toString() {
    return this.constructor.name
  }
}
