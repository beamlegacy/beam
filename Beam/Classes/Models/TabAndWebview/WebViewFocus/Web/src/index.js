import { Native } from "@beam/native-beamtypes"
import {WebViewFocus} from "./WebViewFocus"
import {WebViewFocusUI_native} from "./WebViewFocusUI_native"

const native = Native.getInstance(window, "WebViewFocus")
const WebViewFocusUI = new WebViewFocusUI_native(native)

if (!window.beam) {
  window.beam = {}
}

window.beam.__ID__WebViewFocus = new WebViewFocus(window, WebViewFocusUI)
