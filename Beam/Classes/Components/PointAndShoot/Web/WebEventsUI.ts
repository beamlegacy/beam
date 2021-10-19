import {BeamRect} from "../../../Helpers/Utils/Web/BeamTypes"

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
