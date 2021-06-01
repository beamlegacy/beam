import {PointAndShoot} from "./PointAndShoot"
import {PointAndShootUI_web} from "./PointAndShootUI_web"
import { WebFactory } from "./WebFactory"

const win = window

const pointAndShootUI = new PointAndShootUI_web()
export const __ID__PointAndShoot = PointAndShoot.getInstance(win, pointAndShootUI, new WebFactory())