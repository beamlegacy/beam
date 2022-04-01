import { FrameInfo } from "@beam/native-beamtypes"
import { EventsMock } from "@beam/native-testmock"
import { WebPositionsUI } from "../src/WebPositionsUI"

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
