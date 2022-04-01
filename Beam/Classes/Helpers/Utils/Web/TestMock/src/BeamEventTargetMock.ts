import {BeamEvent, BeamEventTarget} from "@beam/native-beamtypes"

export class BeamEventTargetMock implements BeamEventTarget {
  readonly eventListeners = {}

  addEventListener(type, callback) {
    if (!(type in this.eventListeners)) {
      this.eventListeners[type] = []
    }
    this.eventListeners[type].push(callback)
  }

  removeEventListener(type, callback) {
    if (!(type in this.eventListeners)) {
      return
    }
    const stack = this.eventListeners[type]
    for (let i = 0, l = stack.length; i < l; i++) {
      if (stack[i] === callback) {
        stack.splice(i, 1)
        return
      }
    }
  }

  dispatchEvent(event: BeamEvent) {
    if (!(event.type in this.eventListeners)) {
      return true
    }
    const stack = this.eventListeners[event.type].slice()

    for (let i = 0, l = stack.length; i < l; i++) {
      stack[i].call(this, event)
    }
    return !event.defaultPrevented
  }
}
