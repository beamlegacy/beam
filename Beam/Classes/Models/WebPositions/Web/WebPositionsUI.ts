import {FrameInfo} from "../../../Helpers/Utils/Web/BeamTypes"

export interface WebPositionsUI {
  setFramesInfo(framesInfo: FrameInfo[])

  setScrollInfo(scrollInfo: any)

  setResizeInfo(resizeInfo: any)

  setOnLoadInfo(framesInfo: FrameInfo[])

  pinched(pinchInfo: any)
}
