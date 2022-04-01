import { BeamRect } from "@beam/native-beamtypes"
import { BeamRectHelper } from "../src"

describe("Rectangle matching", () => {

  test("Rects are the same", () => {
    const rect1 = new BeamRect(10, 10, 10, 10)
    const rect2 = new BeamRect(10, 10, 10, 10)
    expect(BeamRectHelper.doRectsMatch(rect1, rect2)).toBe(true)
  })

  test("Rects are not the same", () => {
    const rect1 = new BeamRect(20, 20, 10, 10)
    const rect2 = new BeamRect(10, 10, 10, 10)
    expect(BeamRectHelper.doRectsMatch(rect1, rect2)).toBe(false)
  })
})