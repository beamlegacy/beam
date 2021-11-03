import {BeamWindow, MessagePayload} from "../../BeamTypes"
import {Native} from "../../Native"

export class NativeMock<M> extends Native<M> {

  events = []

  constructor(win: BeamWindow<M>, componentPrefix: string) {
    super(win, componentPrefix)
  }

  sendMessage(name: string, payload: MessagePayload): void {
    this.events.push({name: `sendMessage ${name}`, payload})
  }
}
