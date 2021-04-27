import {Native} from "../Native"
import {BeamWindow} from "../BeamTypes"

export class NativeMock extends Native {

  events = []

  constructor(win: BeamWindow) {
    super(win);
  }

  sendMessage(name: string, payload: {}) {
    this.events.push({name:`sendMessage ${name}`, payload})
  }
}
