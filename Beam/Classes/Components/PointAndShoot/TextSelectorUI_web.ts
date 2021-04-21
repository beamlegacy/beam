import {TextSelectorUI} from "./TextSelectorUI"
import {PointAndShootUI_web} from "./PointAndShootUI_web";

export class TextSelectorUI_web implements TextSelectorUI {
  private prefix = "__ID__"

  private textPointClass = `${this.prefix}-point`

  private textShootClass = `${this.prefix}-shoot`

  /**
   */
  constructor(private pointAndShoot: PointAndShootUI_web) {
    this.log(`${this.toString()} instantiated`)
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

  log(...args) {
    console.log(this.toString(), args)
  }

  toString() {
    return this.constructor.name
  }
}
