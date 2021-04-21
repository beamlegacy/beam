import {TextSelection} from "./TextSelection";

export interface TextSelectorUI {

  enterSelection()

  leaveSelection()

  /**
   * @param selection {TextSelection}
   */
  textSelected(selection: TextSelection)

  /**
   * @param selection {TextSelection}
   */
  addTextSelection(selection: TextSelection)
}
