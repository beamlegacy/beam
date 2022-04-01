import { Native } from "@beam/native-beamtypes"
import {MediaPlayer} from "./MediaPlayer"
import {MediaPlayerUI_native} from "./MediaPlayerUI_native"

const native = Native.getInstance(window, "MediaPlayer")
const MediaPlayerUI = new MediaPlayerUI_native(native)

if (!window.beam) {
  window.beam = {}
}

window.beam.__ID__MediaPlayer = new MediaPlayer(window, MediaPlayerUI)
