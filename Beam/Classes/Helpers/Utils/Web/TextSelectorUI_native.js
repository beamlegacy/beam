import {TextSelectorUI} from "./TextSelectorUI"

export class TextSelectorUI_native extends TextSelectorUI {

  /**
   * @param native {Native}
   */
  constructor(native) {
    super()
    this.native = native
    console.log(`${this} instantiated`)
  }

  toString() {
    return this.constructor.name
  }

  enterSelection(scrollWidth) {
    // TODO: enter selction message
  }

  leaveSelection() {
    // TODO:
  }

  addTextSelection(selection) {
    // TODO: Throttle
    this.native.sendMessage("textSelection", selection)
  }

  textSelected(selection) {
    this.native.sendMessage("textSelected", selection)
  }
}
