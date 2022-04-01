import { Native } from "@beam/native-beamtypes"
import {SearchWebPage} from "./SearchWebPage"
import {SearchWebPageUI_native} from "./SearchWebPageUI_native"

const native = Native.getInstance(window, "SearchWebPage")
const SearchWebPageUI = new SearchWebPageUI_native(native)

if (!window.beam) {
  window.beam = {}
}

window.beam.__ID__SearchWebPage = new SearchWebPage(window, SearchWebPageUI)
