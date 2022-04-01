import {BeamNavigation} from "./BeamNavigation"

if (!window.beam) {
  window.beam = {}
}

window.beam.__ID__Nav = new BeamNavigation(window)
window.beam.__ID__Nav.startHistoryHandling()
