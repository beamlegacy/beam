import {FrameInfo} from "@beam/native-beamtypes"

export interface WebPositionsUI {
  setFramesInfo(framesInfo: FrameInfo[])

  setScrollInfo(scrollInfo: any)

  setResizeInfo(resizeInfo: any)

  setOnLoadInfo(framesInfo: FrameInfo[])

  pinched(pinchInfo: any)
}
