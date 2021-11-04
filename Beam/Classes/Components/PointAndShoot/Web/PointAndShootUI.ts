import {BeamRangeGroup, BeamShootGroup, FrameInfo} from "../../../Helpers/Utils/Web/BeamTypes"

export interface PointAndShootUI {
  prefix: string
  pointBounds(pointTarget?: BeamShootGroup): void
  shootBounds(shootTargets: BeamShootGroup[]): void
  selectBounds(rangeGroups: BeamRangeGroup[]): void
  clearSelection(id: string): void
  hasSelection(hasSelection: boolean): void
  typingOnWebView(isTypingOnWebView: boolean): void
  setFramesInfo(framesInfo: FrameInfo[])
}
