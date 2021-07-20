import {Native} from "../Native"
import {BeamWindow, MessagePayload} from "../BeamTypes"

export class NativeMock extends Native {

  events = []

  constructor(win: BeamWindow) {
    super(win)
  }

  sendMessage(name: string, payload: MessagePayload): void {
    this.events.push({name: `sendMessage ${name}`, payload})
  }
}
