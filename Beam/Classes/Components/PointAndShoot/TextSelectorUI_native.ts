import {TextSelectorUI} from "./TextSelectorUI"
import {Native} from "./Native";

export class TextSelectorUI_native implements TextSelectorUI {

  /**
   * @param native {Native}
   */
  constructor(protected native: Native) {
    this.log('instantiated')
  }

  enterSelection() {
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

  log(...args) {
    console.log(this.toString(), args)
  }
}
