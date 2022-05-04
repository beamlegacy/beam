import { BeamMediaState } from "@beam/native-beamtypes"
export interface MediaPlayerUI {
  media_sendPlayStateChanged(state: BeamMediaState): void
}
