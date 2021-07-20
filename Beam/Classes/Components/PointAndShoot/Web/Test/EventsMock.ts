export class EventsMock {
  /**
   * Recorded calls to this mock UI
   * @type {[]}
   */
  events = []

  constructor() {
    this.log("instantiated")
  }

  get eventsCount() {
    return this.events.length
  }

  get latestEvent() {
    return this.events[this.eventsCount - 1]
  }

  clearEvents() {
    this.events = []
  }

  log(...args) {
    console.log(this.toString(), args)
  }

  toString() {
    return this.constructor.name
  }
}
