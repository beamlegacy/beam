import { EventsMock } from "@beam/native-testmock"
import { MediaPlayerUI } from "../MediaPlayerUI"
import { BeamMediaPlayState } from "@beam/native-beamtypes"

export class MediaPlayerUIMock extends EventsMock implements MediaPlayerUI {
  media_sendPlayStateChanged(state: BeamMediaPlayState): void {
    this.events.push({name: "media_sendPlayStateChanged"})
  }
}
