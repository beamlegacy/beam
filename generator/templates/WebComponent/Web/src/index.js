import { Native } from "@beam/native-beamtypes"
import {__component_name__} from "./__component_name__"
import {__component_name__UI_native} from "./__component_name__UI_native"

const native = Native.getInstance(window, "__component_name__")
const __component_name__UI = new __component_name__UI_native(native)

if (!window.beam) {
  window.beam = {}
}

window.beam.__ID____component_name__ = new __component_name__(window, __component_name__UI)
