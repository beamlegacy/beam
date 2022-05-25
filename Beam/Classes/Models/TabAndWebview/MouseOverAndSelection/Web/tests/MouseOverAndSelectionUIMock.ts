import { EventsMock } from "@beam/native-testmock"
import { MouseOverAndSelectionUI } from "../src/MouseOverAndSelectionUI"

export class MouseOverAndSelectionUIMock extends EventsMock implements MouseOverAndSelectionUI {
  sendLinkMouseOut(arg0: {}) {
    throw new Error("Method not implemented.")
  }
  sendLinkMouseOver(message: { url: any; target: any }) {
    throw new Error("Method not implemented.")
  }
}
