import { EventsMock } from "@beam/native-testmock"
import { EmbedNodeUI } from "../src/EmbedNodeUI"

export class EmbedNodeUIMock extends EventsMock implements EmbedNodeUI {
  sendContentSize() {
    this.events.push({name: "sendContentSize"})
  }
}
