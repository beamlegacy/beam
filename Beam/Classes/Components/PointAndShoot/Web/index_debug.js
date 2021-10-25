import {PointAndShoot} from "./PointAndShoot"
import {Native} from "../../../Helpers/Utils/Web/Native"
import {PointAndShootUI_debug} from "./PointAndShootUI_debug"
import {WebFactory} from "./WebFactory"

const win = window
const native = Native.getInstance(win)

const pointAndShootUI = new PointAndShootUI_debug()

if (!window.beam) {
  window.beam = {}
}

window.beam.__ID__PointAndShoot = PointAndShoot.getInstance(win, pointAndShootUI, new WebFactory())
