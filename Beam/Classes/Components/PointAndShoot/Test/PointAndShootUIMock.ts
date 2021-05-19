import {PointAndShootUI} from "../PointAndShootUI"
import {WebEventsUIMock} from "./WebEventsUIMock";
import {BeamHTMLElement} from "../BeamTypes"

export class PointAndShootUIMock extends WebEventsUIMock implements PointAndShootUI {
  getMouseLocation(el, x, y) {
    this.events.push({name: "getMouseLocation", el, x, y})
  }

  point(quoteId: string, el: BeamHTMLElement, x: number, y: number) {
    this.events.push({name: "point", el, x, y})
  }

  unpoint() {
    this.events.push({name: "unpoint"})
  }

  shoot(quoteId: string, el: BeamHTMLElement, x: number, y: number, selectedEls) {
    this.events.push({name: "shoot", el, x, y, selectedEls})
  }

  unshoot(el: BeamHTMLElement) {
    this.events.push({name: "unshoot", el})
  }

  setStatus(status) {
    this.events.push({name: "setStatus", status})
  }

  hidePopup() {
    this.events.push({name: "hidePopup"})
  }

  hideStatus() {
    this.events.push("hideStatus")
  }

  showStatus(el: BeamHTMLElement, collected) {
    this.events.push({name: "showStatus", el, collected})
  }

  enterSelection() {
    this.events.push({name: "enterSelection"})
  }

  leaveSelection() {
    this.events.push({name: "leaveSelection"})
  }

  addTextSelection(selection) {
    this.events.push({name: "addTextSelection", selection})
  }

  textSelected(selection) {
    this.events.push({name: "textSelected", selection})
  }
}
