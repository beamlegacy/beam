import { MediaPlayerUI } from "./MediaPlayerUI"
import {
  BeamLogCategory,
  BeamMediaState,
  BeamWindow,
  Native
} from "@beam/native-beamtypes"
import { BeamLogger } from "@beam/native-utils"

export class MediaPlayerUI_native implements MediaPlayerUI {
  logger: BeamLogger
  /**
   * @param native {Native}
   */
  constructor(protected native: Native<any>) {
    this.logger = new BeamLogger(this.native.win, BeamLogCategory.embedNode)
  }

  /**
   *
   * @param win {BeamWindow}
   * @returns {MediaPlayerUI_native}
   */
  static getInstance(win: BeamWindow): MediaPlayerUI_native {
    let instance
    try {
      const native = Native.getInstance(win, "MediaPlayer")
      instance = new MediaPlayerUI_native(native)
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(e)
      instance = null
    }
    return instance
  }

  media_sendPlayStateChanged({
    playState,
    muted,
    pipSupported,
    isInPip
  }: BeamMediaState): void {
    this.native.sendMessage("media_playing_changed", {
      playState,
      muted,
      pipSupported,
      isInPip
    })
  }

  toString(): string {
    return this.constructor.name
  }
}
