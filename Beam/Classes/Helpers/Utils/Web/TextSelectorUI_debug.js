import {TextSelectorUI} from "./TextSelectorUI"

export class TextSelectorUI_debug extends TextSelectorUI {
  /**
   * @type UI_web
   */
  webUi

  /**
   * @type UI_native
   */
  nativeUi

  /**
   *
   * @param nativeUI {UI_native}
   * @param webUi {UI_web}
   */
  constructor(nativeUI, webUi) {
    super()
    this.webUi = webUi
    this.nativeUi = nativeUI
  }

  enterSelection(scrollWidth) {
    this.webUi.textSelector.enterSelection(scrollWidth)
    this.nativeUi.textSelector.enterSelection()
  }

  leaveSelection() {
    this.webUi.textSelector.leaveSelection()
    this.nativeUi.textSelector.leaveSelection()
  }

  addTextSelection(selection) {
    this.webUi.textSelector.addTextSelection(selection)
    this.nativeUi.textSelector.addTextSelection(selection)
  }

  textSelected(selection) {
    this.webUi.textSelector.textSelected(selection)
    this.nativeUi.textSelector.textSelected(selection)
  }
}
