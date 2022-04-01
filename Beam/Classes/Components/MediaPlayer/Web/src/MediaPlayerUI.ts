import { BeamMediaPlayState } from "@beam/native-beamtypes"
export interface MediaPlayerUI {
  media_sendPlayStateChanged(state: BeamMediaPlayState): void
}
