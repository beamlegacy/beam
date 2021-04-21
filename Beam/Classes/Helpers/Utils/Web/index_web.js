import {PointAndShoot} from "./PointAndShoot"
import {TextSelector} from "./TextSelector"
import {TextSelectorUI_web} from "./TextSelectorUI_web"
import {PointAndShootUI_web} from "./PointAndShootUI_web"

const win = window

const pointAndShootUI = new PointAndShootUI_web()
export const __ID__PointAndShoot = PointAndShoot.getInstance(win, pointAndShootUI)

const textSelectorUI = new TextSelectorUI_web(pointAndShootUI)
new TextSelector(win, textSelectorUI)
