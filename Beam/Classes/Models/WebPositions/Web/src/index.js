import { Native } from "@beam/native-beamtypes"
import {WebPositions} from "./WebPositions"
import {WebPositionsUI_native} from "./WebPositionsUI_native"

const native = Native.getInstance(window, "WebPositions")
const WebPositionsUI = new WebPositionsUI_native(native)

if (!window.beam) {
  window.beam = {}
}

window.beam.__ID__WebPositions = new WebPositions(window, WebPositionsUI)
