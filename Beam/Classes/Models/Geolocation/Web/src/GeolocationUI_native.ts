import { GeolocationUI } from "./GeolocationUI"
import {
  BeamLogCategory,
  BeamWindow,
  Native
} from "@beam/native-beamtypes"
import { BeamLogger } from "@beam/native-utils"

export class GeolocationUI_native implements GeolocationUI {
  logger: BeamLogger
  /**
   * @param native {Native}
   */
  constructor(protected native: Native<any>) {
    this.logger = new BeamLogger(this.native.win, BeamLogCategory.embedNode)
    this.logger.log(`${this.toString()} instantiated`)
  }

  /**
   *
   * @param win {BeamWindow}
   * @returns {GeolocationUI_native}
   */
  static getInstance(win: BeamWindow): GeolocationUI_native {
    let instance
    try {
      const native = Native.getInstance(win, "Geolocation")
      instance = new GeolocationUI_native(native)
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(e)
      instance = null
    }
    return instance
  }

  listenerAdded(): void {
    this.native.sendMessage("listenerAdded", {})
  }

  listenerRemmoved(): void {
    this.native.sendMessage("listenerRemoved", {})
  }

  toString(): string {
    return this.constructor.name
  }
}
