import { EventsMock } from "@beam/native-testmock"
import { __component_name__UI } from "../src/__component_name__UI"

export class __component_name__UIMock extends EventsMock implements __component_name__UI {
  sendContentSize() {
    this.events.push({name: "sendContentSize"})
  }
}
