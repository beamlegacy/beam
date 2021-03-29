import {PointAndShoot} from "./PointAndShoot"

class TestUI {

  setFramesInfo(framesInfo) {
    this.framesInfo = framesInfo
  }

  setScrollInfo(scrollInfo) {
    this.scrollInfo = scrollInfo
  }
}

test("instantiate", () => {
  const ui = new TestUI();
  const pns = PointAndShoot(ui)
})