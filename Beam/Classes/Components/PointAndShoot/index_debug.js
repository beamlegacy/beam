import {PointAndShoot} from "./PointAndShoot"
import {Native} from "./Native"
import {PointAndShootUI_debug} from "./PointAndShootUI_debug"
import { WebFactory } from "./WebFactory"

const win = window
const native = Native.getInstance(win)

const pointAndShootUI = new PointAndShootUI_debug()
export const __ID__PointAndShoot = PointAndShoot.getInstance(win, pointAndShootUI, new WebFactory())