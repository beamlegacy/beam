import {PointAndShoot} from "./PointAndShoot"
import {PointAndShootUI_native} from "./PointAndShootUI_native"
import {TextSelectorUI_native} from "./TextSelectorUI_native"
import {Native} from "./Native"
import {TextSelector} from "./TextSelector"

const win = window

const native = Native.getInstance(win)

const pointAndShootUI = new PointAndShootUI_native(native)
export const __ID__PointAndShoot = PointAndShoot.getInstance(win, pointAndShootUI)

const textSelectorUI = new TextSelectorUI_native(native)
new TextSelector(win, textSelectorUI)
