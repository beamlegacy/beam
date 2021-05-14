import {PointAndShootUI} from "../PointAndShootUI"
import {WebEventsUIMock} from "./WebEventsUIMock";

export class PointAndShootUIMock extends WebEventsUIMock implements PointAndShootUI {
  getMouseLocation(el, x, y) {
    this.events.push({name: "getMouseLocation", el, x, y})
  }

  point(quoteId, el, x, y) {
    this.events.push({name: "point", el, x, y})
  }

  unpoint() {
    this.events.push({name: "unpoint"})
  }

  shoot(quoteId, el, x, y, selectedEls) {
    this.events.push({name: "shoot", el, x, y, selectedEls})
  }

  unshoot(el) {
    this.events.push({name: "unshoot", el})
  }

  setStatus(status) {
    this.events.push({name: "setStatus", status})
  }

  enterSelection() {
    this.events.push({name: "enterSelection"})
  }

  hidePopup() {
    this.events.push({name: "hidePopup"})
  }

  hideStatus() {
    this.events.push("hideStatus")
  }

  leaveSelection() {
    this.events.push({name: "leaveSelection"})
  }

  showStatus(el, collected) {
    this.events.push({name: "showStatus", el, collected})
  }
}
