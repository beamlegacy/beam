import { EventsMock } from "@beam/native-testmock"
import { ContextMenuUI } from "../src/ContextMenuUI"

export class ContextMenuUIMock extends EventsMock implements ContextMenuUI {
  sendContentSize() {
    this.events.push({name: "sendContentSize"})
  }
}
