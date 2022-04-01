import { EventsMock } from "@beam/native-testmock"
import { LinkMouseOverUI } from "../src/LinkMouseOverUI"

export class LinkMouseOverUIMock extends EventsMock implements LinkMouseOverUI {
  sendLinkMouseOut(arg0: {}) {
    throw new Error("Method not implemented.")
  }
  sendLinkMouseOver(message: { url: any; target: any }) {
    throw new Error("Method not implemented.")
  }
}
