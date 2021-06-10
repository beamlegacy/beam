import { FrameInfo, WebEventsUI } from "../WebEventsUI"
import { EventsMock } from "./EventsMock"

export class WebEventsUIMock extends EventsMock implements WebEventsUI {
  setFramesInfo(framesInfo: FrameInfo[]) {
    this.events.push({ name: "frames", framesInfo })
  }

  setScrollInfo(scrollInfo) {
    this.events.push({ name: "scroll", ...scrollInfo })
  }

  pinched(pinchInfo: any) {
    this.events.push({ name: "pinched", ...pinchInfo })
  }

  setOnLoadInfo() {
    this.events.push({ name: "onLoad" })
  }

  setResizeInfo(resizeInfo: any) {
    this.events.push({ name: "resize", ...resizeInfo })
  }
}
