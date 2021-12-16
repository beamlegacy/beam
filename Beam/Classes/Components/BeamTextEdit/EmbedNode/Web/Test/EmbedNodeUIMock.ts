import { EventsMock } from "../../../../../Helpers/Utils/Web/Test/Mock/EventsMock"
import { EmbedNodeUI } from "../EmbedNodeUI"

export class EmbedNodeUIMock extends EventsMock implements EmbedNodeUI {
  sendContentSize() {
    this.events.push({name: "sendContentSize"})
  }
}
