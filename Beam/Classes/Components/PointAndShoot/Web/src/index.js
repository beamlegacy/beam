import {PointAndShoot} from "./PointAndShoot"
import {PointAndShootUI_native} from "./PointAndShootUI_native"
import {Native} from "@beam/native-beamtypes"

const native = Native.getInstance(window, "pointAndShoot")
const pointAndShootUI = new PointAndShootUI_native(native)

if (!window.beam) {
  window.beam = {}
}

window.beam.__ID__PointAndShoot = PointAndShoot.getInstance(window, pointAndShootUI)