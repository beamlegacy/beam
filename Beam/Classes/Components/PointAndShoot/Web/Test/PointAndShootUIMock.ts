import { PointAndShootUI } from "../PointAndShootUI"
import { WebEventsUIMock } from "./WebEventsUIMock"
import { BeamRangeGroup, BeamShootGroup } from "../BeamTypes"

export class PointAndShootUIMock extends WebEventsUIMock implements PointAndShootUI {
  isTypingOnWebView(isTypingOnWebView: boolean): void {
      this.events.push({name: "isTypingOnWebView", isTypingOnWebView})
  }
  pointBounds(pointTarget?: BeamShootGroup): void {
    this.events.push({name: "pointBounds", pointTarget})
  }
  selectBounds(rangeGroups: BeamRangeGroup[]): void {
    this.events.push({name: "selectBounds", rangeGroups})
  }
  shootBounds(shootTargets: BeamShootGroup[]): void {
    this.events.push({name: "shootBounds", shootTargets})
  }
  clearSelection(id: string): void {
    this.events.push({name: "clearSelection", id})
  }
  hasSelection(hasSelection: boolean): void {
    this.events.push({name: "hasSelection", hasSelection})
  }
}
