import { Native } from "../../../../Helpers/Utils/Web/Native"
import {EmbedNode} from "./EmbedNode"
import {EmbedNodeUI_native} from "./EmbedNodeUI_native"

const native = Native.getInstance(window, "EmbedNode")
const EmbedNodeUI = new EmbedNodeUI_native(native)

if (!window.beam) {
  window.beam = {}
}

window.beam.__ID__EmbedNode = new EmbedNode(window, EmbedNodeUI)
