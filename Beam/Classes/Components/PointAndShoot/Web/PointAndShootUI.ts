import { WebEventsUI } from "./WebEventsUI"
import { BeamRangeGroup, BeamShootGroup } from "./BeamTypes"

export interface PointAndShootUI extends WebEventsUI {
  pointBounds(pointTarget?: BeamShootGroup): void
  shootBounds(shootTargets: BeamShootGroup[]): void
  selectBounds(rangeGroups: BeamRangeGroup[]): void
  clearSelection(id: string): void
  hasSelection(hasSelection: boolean): void
  isTypingOnWebView(isTypingOnWebView: boolean): void
}
