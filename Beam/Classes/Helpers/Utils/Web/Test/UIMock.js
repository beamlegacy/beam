import {UI} from "../UI"
import {BeamHTMLElement} from "./BeamMocks"

export class UIMock extends UI {

  /**
   * Recorded calls to this mock UI
   * @type {[]}
   */
  events = []

  get latestEvent() {
    return this.events[this.eventsCount - 1]
  }

  get eventsCount() {
    return this.events.length
  }

  setFramesInfo(framesInfo) {
    this.events.push({name: "frames", framesInfo})
  }

  setScrollInfo(scrollInfo) {
    this.events.push({name: "scroll", ...scrollInfo})
  }

  point(el, x, y) {
    this.events.push({name: "point", el, x, y})
  }

  unpoint() {
    this.events.push({name: "unpoint"})
  }

  shoot(el, x, y, selectedEls, _submitCb) {
    this.events.push({name: "shoot", el, x, y, selectedEls})
  }

  unshoot(el) {
    this.events.push({name: "unshoot", el})
  }

  setStatus(status) {
    this.events.push({name: "setStatus", status})
  }

  clearEvents() {
    this.events = []
  }
}
