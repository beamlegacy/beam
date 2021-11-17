import {PointAndShoot} from "./PointAndShoot"
import {PointAndShootUI_debug} from "./PointAndShootUI_debug"

const win = window

const pointAndShootUI = new PointAndShootUI_debug()

if (!window.beam) {
  window.beam = {}
}

window.beam.__ID__PointAndShoot = PointAndShoot.getInstance(win, pointAndShootUI)
