import { PointAndShootUI } from "../PointAndShootUI"
import { WebEventsUIMock } from "./WebEventsUIMock"
import { BeamElement, BeamRange, BeamRangeGroup, BeamShootGroup } from "../BeamTypes"

export class PointAndShootUIMock extends WebEventsUIMock implements PointAndShootUI {
  pointBounds(pointTarget?: BeamShootGroup) {
    this.events.push({name: "pointBounds", pointTarget})
  }
  selectBounds(rangeGroups: BeamRangeGroup[]) {
    this.events.push({name: "selectBounds", rangeGroups})
  }
  shootBounds(shootTargets: BeamShootGroup[]) {
    this.events.push({name: "shootBounds", shootTargets})
  }
  hasSelection(hasSelection: boolean) {
    this.events.push({name: "hasSelection", hasSelection})
  }
}
