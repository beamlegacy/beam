import {PointAndShootUI} from "./PointAndShootUI"

export class PointAndShootUI_debug extends PointAndShootUI {

  nativeUi
  webUi

  /**
   *
   * @param nativeUi {PointAndShootUI_native}
   * @param webUi {PointAndShootUI_web}
   */
  constructor(nativeUi, webUi) {
    super()
    this.nativeUi = nativeUi
    this.webUi = webUi
  }

  point(el, x, y) {
    this.webUi.point(el)
    this.nativeUi.point(el, x, y)
  }

  unpoint(el) {
    this.webUi.unpoint(el)
    this.nativeUi.unpoint(el)
  }

  shoot(el, x, y, selected, submitCb) {
    this.webUi.shoot(el, x, y, selected, submitCb)
    this.nativeUi.shoot(el, x, y, selected, submitCb)
  }
}
