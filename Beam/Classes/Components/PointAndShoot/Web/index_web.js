import {PointAndShoot} from "./PointAndShoot"
import {PointAndShootUI_web} from "./PointAndShootUI_web"

const win = window

const pointAndShootUI = new PointAndShootUI_web()

if (!window.beam) {
  window.beam = {}
}

window.beam.__ID__PointAndShoot = PointAndShoot.getInstance(win, pointAndShootUI)
