import { BeamRect } from "./BeamTypes"

export class FrameInfo {
  /**
   */
  href: string

  /**
   */
  bounds: BeamRect
}

export interface WebEventsUI {
  setFramesInfo(framesInfo: FrameInfo[])

  setScrollInfo(scrollInfo: any)

  setResizeInfo(resizeInfo: any)

  setOnLoadInfo(framesInfo: FrameInfo[])

  pinched(pinchInfo: any)
}
