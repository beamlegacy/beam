import {TextSelectorUI} from "./TextSelectorUI"

export class TextSelectorUI_debug extends TextSelectorUI {
  /**
   * @type TextSelectorUI_native
   */
  native

  /**
   * @type TextSelectorUI_web
   */
  web

  /**
   *
   * @param native {TextSelectorUI_native}
   * @param web {TextSelectorUI_web}
   */
  constructor(native, web) {
    super()
    this.native = native
    this.web = web
  }

  enterSelection(scrollWidth) {
    this.web.enterSelection()
    this.native.enterSelection()
  }

  leaveSelection() {
    this.web.leaveSelection()
    this.native.leaveSelection()
  }

  addTextSelection(selection) {
    this.web.addTextSelection(selection)
    this.native.addTextSelection(selection)
  }

  textSelected(selection) {
    this.web.textSelected(selection)
    this.native.textSelected(selection)
  }
}
