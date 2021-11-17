import {PointAndShootUI} from "../PointAndShootUI"
import {BeamRangeGroup, BeamShootGroup, FrameInfo} from "../../../../Helpers/Utils/Web/BeamTypes"
import { EventsMock } from "../../../../Helpers/Utils/Web/Test/Mock/EventsMock"

export class PointAndShootUIMock extends EventsMock implements PointAndShootUI {
  setFramesInfo(framesInfo: FrameInfo[]): void {
    this.events.push({name: "frames", framesInfo})
  }
  prefix: string  
  typingOnWebView(isTypingOnWebView: boolean): void {
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
