import { SearchWebPageUI } from "./SearchWebPageUI"
import {
  BeamLogCategory,
  BeamWindow,
  Native
} from "@beam/native-beamtypes"
import { BeamLogger } from "@beam/native-utils"

export class SearchWebPageUI_native implements SearchWebPageUI {
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
   * @returns {SearchWebPageUI_native}
   */
  static getInstance(win: BeamWindow): SearchWebPageUI_native {
    let instance
    try {
      const native = Native.getInstance(win, "SearchWebPage")
      instance = new SearchWebPageUI_native(native)
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(e)
      instance = null
    }
    return instance
  }

  webPageSearch(payload: { currentResult?: number; totalResults?: number; positions?: undefined[]; height?: number; incompleteSearch?: boolean; currentSelected?: boolean }) {
    this.native.sendMessage("webPageSearch", payload)
  }
  webSearchCurrentSelection(selection: string) {
    this.native.sendMessage("webSearchCurrentSelection", { selection })
  }

  toString(): string {
    return this.constructor.name
  }
}
