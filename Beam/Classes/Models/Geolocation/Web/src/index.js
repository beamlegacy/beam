import { Native } from "@beam/native-beamtypes"
import {Geolocation} from "./Geolocation"
import {GeolocationUI_native} from "./GeolocationUI_native"

const native = Native.getInstance(window, "Geolocation")
const GeolocationUI = new GeolocationUI_native(native)

if (!window.beam) {
  window.beam = {}
}

window.beam.__ID__Geolocation = new Geolocation(window, GeolocationUI)
