import { Native } from "@beam/native-beamtypes"
import {ContextMenu} from "./ContextMenu"
import {ContextMenuUI_native} from "./ContextMenuUI_native"

const native = Native.getInstance(window, "ContextMenu")
const ContextMenuUI = new ContextMenuUI_native(native)

if (!window.beam) {
  window.beam = {}
}

window.beam.__ID__ContextMenu = new ContextMenu(window, ContextMenuUI)
