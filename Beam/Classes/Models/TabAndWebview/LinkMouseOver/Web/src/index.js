import { Native } from "@beam/native-beamtypes"
import {LinkMouseOver} from "./LinkMouseOver"
import {LinkMouseOverUI_native} from "./LinkMouseOverUI_native"

const native = Native.getInstance(window, "LinkMouseOver")
const LinkMouseOverUI = new LinkMouseOverUI_native(native)

if (!window.beam) {
  window.beam = {}
}

window.beam.__ID__LinkMouseOver = new LinkMouseOver(window, LinkMouseOverUI)
