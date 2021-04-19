import {PointAndShoot} from "./PointAndShoot"
import {UI_web} from "./UI_web"

const ui = UI_web.getInstance(window)

PointAndShoot.getInstance(window, ui)
