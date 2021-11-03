import { FrameInfo } from "../../../../Helpers/Utils/Web/BeamTypes"
import { EventsMock } from "../../../../Helpers/Utils/Web/Test/Mock/EventsMock"
import { WebPositionsUI } from "../WebPositionsUI"

export class WebPositionsUIMock extends EventsMock implements WebPositionsUI {
  setFramesInfo(framesInfo: FrameInfo[]) {
    this.events.push({name: "frames", framesInfo})
  }

  setScrollInfo(scrollInfo) {
    this.events.push({name: "scroll", ...scrollInfo})
  }

  pinched(pinchInfo: any) {
    this.events.push({name: "pinched", ...pinchInfo})
  }

  setOnLoadInfo() {
    this.events.push({name: "onLoad"})
  }

  setResizeInfo(resizeInfo: any) {
    this.events.push({name: "resize", ...resizeInfo})
  }
}
