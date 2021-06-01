import {PointAndShoot} from "./PointAndShoot"
import {PointAndShootUI_native} from "./PointAndShootUI_native"
import {Native} from "./Native"
import { WebFactory } from "./WebFactory"

const win = window
const native = Native.getInstance(win)

const pointAndShootUI = new PointAndShootUI_native(native)
export const __ID__PointAndShoot = PointAndShoot.getInstance(win, pointAndShootUI, new WebFactory())