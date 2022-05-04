import {
  BeamElement,
  BeamLogCategory,
  BeamWebkitPresentationMode,
  BeamWindow,
  MediaPlayState
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
              tag.addEventListener("pause", this.media_onPausePlaying.bind(this))
              tag.addEventListener("ended", this.media_onStopPlaying.bind(this))
          }
      }
  }

  /**
   * Reduces all media element states into a single state.
   *
   * @return {*}  {MediaPlayState}
   * @memberof MediaPlayer
   */
  getPlayStateFromAllTags(): MediaPlayState {
    const tags = this.media_htmlMediaTags()
    const states = []
    for (let i = 0; i < tags.length; i++) {
        states.push(this.getPlayStateFromTag(tags[i]))
    }

    if (states.includes(MediaPlayState.playing)) {
      return MediaPlayState.playing
    }

    if (states.includes(MediaPlayState.paused)) {
      return MediaPlayState.paused
    }

    if (states.includes(MediaPlayState.ended)) {
      return MediaPlayState.ended
    }

    return MediaPlayState.ready
  }

  /**
   * Returns playstate of html element
   *
   * @param {*} element
   * @return {*}  {MediaPlayState}
   * @memberof MediaPlayer
   */
  getPlayStateFromTag(element): MediaPlayState {
    const {currentTime, paused, muted, ended} = element

    if (ended) {
      return MediaPlayState.ended
    }

    if (currentTime == 0 && paused) {
      return MediaPlayState.ready
    }

    const isMutedByDefault = muted && !this.media_isPageMuted    
    if (!paused && !isMutedByDefault) {
      return MediaPlayState.playing
    }
    
    return MediaPlayState.paused
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

  media_onPausePlaying(event) {
    this.sendPlayState(event.target)
  }

  media_onStopPlaying(event) {
    this.sendPlayState(event.target)
  }

  sendPlayState(element: BeamElement) {
    const playState = {
      playState: this.getPlayStateFromAllTags(),
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
