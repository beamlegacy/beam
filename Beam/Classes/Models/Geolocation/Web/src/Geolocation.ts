import {
  BeamEmbedContentSize,
  BeamLogCategory,
  BeamWindow
} from "@beam/native-beamtypes"
import type { GeolocationUI as GeolocationUI } from "./GeolocationUI"
import { BeamLogger } from "@beam/native-utils"

export class Geolocation<UI extends GeolocationUI> {
  win: BeamWindow
  logger: BeamLogger

  /**
   * Singleton
   *
   * @type Geolocation
   */
  static instance: Geolocation<any>

  /**
   * @param win {(BeamWindow)}
   * @param ui {GeolocationUI}
   */
  constructor(win: BeamWindow<any>, protected ui: UI) {
    this.win = win
    this.logger = new BeamLogger(win, BeamLogCategory.embedNode)
    this.overrideNavigatorGeolocation()
  }

  listeners = {}

  overrideNavigatorGeolocation(): void {
    // @override getCurrentPosition()
    navigator.geolocation.getCurrentPosition = function (
      success,
      error,
      options
    ) {
      var id = this.id()
      this.listeners[id] = {
        onetime: true,
        success: success || this.noop,
        error: error || this.noop
      }
      this.ui.listenerAdded()
    }

    // @override watchPosition()
    navigator.geolocation.watchPosition = function (success, error, options) {
      var id = this.id()
      this.listeners[id] = {
        onetime: false,
        success: success || this.noop,
        error: error || this.noop
      }
      this.ui.listenerAdded()
      return id
    }

    // @override clearWatch()
    navigator.geolocation.clearWatch = function (id) {
      var idExists = this.listeners[id] ? true : false
      if (idExists) {
        this.listeners[id] = null
        delete this.listeners[id]
        this.ui.listenerRemoved()
      }
    }
  }

  noop() {}

  id() {
    var min = 1,
      max = 1000
    return Math.floor(Math.random() * (max - min + 1)) + min
  }

  clear(isError) {
    for (var id in this.listeners) {
      if (isError || this.listeners[id].onetime) {
        navigator.geolocation.clearWatch(Number(id))
      }
    }
  }

  success(
    timestamp,
    latitude,
    longitude,
    altitude,
    accuracy,
    altitudeAccuracy,
    heading,
    speed
  ) {
    var position = {
      timestamp: new Date(timestamp).getTime() || new Date().getTime(), // safari can not parse date format returned by swift e.g. 2019-12-27 15:46:59 +0000 (fallback used because we trust that safari will learn it in future because chrome knows that format)
      coords: {
        latitude: latitude,
        longitude: longitude,
        altitude: altitude,
        accuracy: accuracy,
        altitudeAccuracy: altitudeAccuracy,
        heading: heading > 0 ? heading : null,
        speed: speed > 0 ? speed : null
      }
    }
    for (var id in this.listeners) {
      this.listeners[id].success(position)
    }
    this.clear(false)
  }

  error(code, message) {
    var error = {
      PERMISSION_DENIED: 1,
      POSITION_UNAVAILABLE: 2,
      TIMEOUT: 3,
      code: code,
      message: message
    }
    for (var id in this.listeners) {
      this.listeners[id].error(error)
    }
    this.clear(true)
  }

  toString(): string {
    return this.constructor.name
  }
}
