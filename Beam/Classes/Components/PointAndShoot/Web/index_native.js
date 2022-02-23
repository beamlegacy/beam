import {PointAndShoot} from "./PointAndShoot"
import {PointAndShootUI_native} from "./PointAndShootUI_native"
import {Native} from "../../../Helpers/Utils/Web/Native"

const win = window
const native = Native.getInstance(win, "pointAndShoot")

const pointAndShootUI = new PointAndShootUI_native(native)

if (!window.beam) {
  window.beam = {}
}

window.beam.__ID__PointAndShoot = PointAndShoot.getInstance(win, pointAndShootUI)