import {
  BeamElement,
  BeamLogCategory,
  BeamWebkitPresentationMode,
  BeamWindow
} from "@beam/native-beamtypes"
import type { MediaPlayerUI as MediaPlayerUI } from "./MediaPlayerUI"
import { BeamLogger } from "@beam/native-utils"

export class MediaPlayer<UI extends MediaPlayerUI> {
  win: BeamWindow
  logger: BeamLogger

  media_isPageMuted = false

  /**
   * Singleton
   *
   * @type MediaPlayer
   */
  static instance: MediaPlayer<any>

  /**
   * @param win {(BeamWindow)}
   * @param ui {MediaPlayerUI}
   */
  constructor(win: BeamWindow<any>, protected ui: UI) {
    this.win = win
    this.logger = new BeamLogger(win, BeamLogCategory.embedNode)
    this.registerEventListeners()
  }

  registerEventListeners(): void {
    this.win.addEventListener("load", this.media_observe.bind(this))
    this.win.addEventListener("beam_historyLoad", this.media_onPlaying.bind(this)) 
  }

  media_htmlMediaTags() {
      return this.win.document.querySelectorAll("video,audio")
  }

  media_observe() {
      const tags = this.media_htmlMediaTags()
      for (let i = 0; i < tags.length; i++) {
          const tag = tags[i]
          if (tag.addEventListener) {
              tag.addEventListener("playing", this.media_onPlaying.bind(this))
              tag.addEventListener("pause", this.media_onStopPlaying.bind(this))
              tag.addEventListener("ended", this.media_onStopPlaying.bind(this))
          }
      }
  }

  media_isAnyMediaPlaying() {
      const tags = this.media_htmlMediaTags()
      for (let i = 0; i < tags.length; i++) {
          const tag = tags[i]
          const isMutedByDefault = tag.muted && !this.media_isPageMuted
          if (!tag.paused && !isMutedByDefault) {
              return true
          }
      }
      return false
  }

  media_toggleMute() {
      this.media_isPageMuted = !this.media_isPageMuted
      const tags = this.media_htmlMediaTags()
      for (let i = 0; i < tags.length; i++) {
          const tag = tags[i]
          tag.muted = this.media_isPageMuted
      }
  }

  media_elemenSupportsPictureInPicture(element) {
      return element.webkitSupportsPresentationMode !== undefined && typeof element.webkitSetPresentationMode === "function"
  }

  media_elemenIsInPictureInPicture(element) {
      return this.media_elemenSupportsPictureInPicture(element) && element.webkitPresentationMode === "picture-in-picture"
  }

  media_togglePictureInPicture() {
      const tags = this.media_htmlMediaTags()
      if (tags.length == 0) { return }
      for (let i = 0; i < tags.length; i++) {
          const tag = tags[i]
          if (this.media_elemenSupportsPictureInPicture(tag)) {
              const isInPip = this.media_elemenIsInPictureInPicture(tag)
              const presentationMode = isInPip ? BeamWebkitPresentationMode.inline : BeamWebkitPresentationMode.pip
              tag.webkitSetPresentationMode(presentationMode)
              return
          }
      }
  }

  media_onPlaying(event) {
      if (this.media_isPageMuted && event.target.muted == false) {
          // mute any appearing playing element if we muted.
          event.target.muted = this.media_isPageMuted
      }
      this.sendPlayState(event.target)
  }

  media_onStopPlaying(event) {
    this.sendPlayState(event.target)
  }

  sendPlayState(element: BeamElement) {
    const playState = {
      playing: this.media_isAnyMediaPlaying(),
      muted: this.media_isPageMuted,
      "pipSupported": this.media_elemenSupportsPictureInPicture(element),
      "isInPip": this.media_elemenIsInPictureInPicture(element)
    }
  this.ui.media_sendPlayStateChanged(playState)
  }

  toString(): string {
    return this.constructor.name
  }
}
