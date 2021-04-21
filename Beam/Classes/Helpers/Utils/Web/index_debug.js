import {PointAndShoot} from "./PointAndShoot"
import {Native} from "./Native"
import {TextSelector} from "./TextSelector"
import {TextSelectorUI_debug} from "./TextSelectorUI_debug"
import {PointAndShootUI_debug} from "./PointAndShootUI_debug"
import {TextSelectorUI_native} from "./TextSelectorUI_native"
import {TextSelectorUI_web} from "./TextSelectorUI_web"

const win = window

const native = Native.getInstance(win)

const pointAndShootUI = new PointAndShootUI_debug()
export const __ID__PointAndShoot = PointAndShoot.getInstance(win, pointAndShootUI)

const textSelectorUI_native = new TextSelectorUI_native(native)
const textSelectorUI_web = new TextSelectorUI_web()
const textSelectorUI = new TextSelectorUI_debug(textSelectorUI_native, textSelectorUI_web)
new TextSelector(win, textSelectorUI)
