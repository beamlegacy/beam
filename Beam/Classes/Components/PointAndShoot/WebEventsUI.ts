export class FrameInfo {
  /**
   * @type string
   */
  href

  /**
   * @type {BeamRect}
   */
  bounds
}

export interface WebEventsUI {

  setFramesInfo(framesInfo: FrameInfo[])

  setScrollInfo(scrollInfo: any)

  setResizeInfo(resizeInfo: any)

  setOnLoadInfo()

  pinched(pinchInfo: any)
}
