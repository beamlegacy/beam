import { Native } from "@beam/native-beamtypes"
import {PasswordManager} from "./PasswordManager"
import {PasswordManagerUI_native} from "./PasswordManagerUI_native"

const native = Native.getInstance(window, "PasswordManager")
const PasswordManagerUI = new PasswordManagerUI_native(native)

if (!window.beam) {
  window.beam = {}
}

window.beam.__ID__PasswordManager = new PasswordManager(window, PasswordManagerUI)
