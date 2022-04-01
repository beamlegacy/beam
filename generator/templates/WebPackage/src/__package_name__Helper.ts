import { BeamRect } from "@beam/native-beamtypes"

export class __package_name__Helper {
  static doRectsMatch(rect1: BeamRect, rect2: BeamRect): boolean {
    return (
      Math.round(rect1?.x) == Math.round(rect2?.x) &&
      Math.round(rect1?.y) == Math.round(rect2?.y) &&
      Math.round(rect1?.height) == Math.round(rect2?.height) &&
      Math.round(rect1?.width) == Math.round(rect2?.width)
    )
  }
}
