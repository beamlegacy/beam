import {TextSelectorUI} from "../TextSelectorUI";
import {EventsMock} from "./EventsMock";

export class TextSelectorUI_mock extends EventsMock implements TextSelectorUI {

  /**
   */
  constructor() {
    super()
  }

  enterSelection() {
    this.events.push({name: "enterSelection"})
  }

  leaveSelection() {
    this.events.push({name: "leaveSelection"})
  }

  addTextSelection(selection) {
    this.events.push({name: "addTextSelection", selection})
  }

  textSelected(selection) {
    this.events.push({name: "textSelected", selection})
  }
}
