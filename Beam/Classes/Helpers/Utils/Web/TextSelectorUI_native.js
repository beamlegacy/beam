import {TextSelectorUI} from "./TextSelectorUI"

export class TextSelectorUI_native extends TextSelectorUI {

  /**
   * @param native {Native}
   */
  constructor(native) {
    super()
    this.native = native
    this.log('instantiated')
  }

  log(...args) {
    console.log(this.toString(), args)
  }

  enterSelection(scrollWidth) {
    // TODO: enterSelection message?
  }

  leaveSelection() {
    this.log("leaveSelection")
    // TODO: leaveSelection message?
  }

  addTextSelection(selection) {
    // TODO: Throttle
    this.native.sendMessage("textSelection", selection)
  }

  textSelected(selection) {
    this.native.sendMessage("textSelected", selection)
  }

  toString() {
    return this.constructor.name
  }
}
