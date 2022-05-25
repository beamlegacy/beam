import { Native } from "@beam/native-beamtypes"
import {MouseOverAndSelection} from "./MouseOverAndSelection"
import {MouseOverAndSelectionUI_native} from "./MouseOverAndSelectionUI_native"

const native = Native.getInstance(window, "MouseOverAndSelection")
const MouseOverAndSelectionUI = new MouseOverAndSelectionUI_native(native)

if (!window.beam) {
  window.beam = {}
}

window.beam.__ID__MouseOverAndSelection = new MouseOverAndSelection(window, MouseOverAndSelectionUI)
