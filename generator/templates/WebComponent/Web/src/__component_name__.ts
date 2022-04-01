import {
  BeamEmbedContentSize,
  BeamLogCategory,
  BeamWindow
} from "@beam/native-beamtypes"
import type { __component_name__UI as __component_name__UI } from "./__component_name__UI"
import { BeamLogger } from "@beam/native-utils"

export class __component_name__<UI extends __component_name__UI> {
  win: BeamWindow
  logger: BeamLogger

  /**
   * Singleton
   *
   * @type __component_name__
   */
  static instance: __component_name__<any>

  /**
   * @param win {(BeamWindow)}
   * @param ui {__component_name__UI}
   */
  constructor(win: BeamWindow<any>, protected ui: UI) {
    this.win = win
    this.logger = new BeamLogger(win, BeamLogCategory.embedNode)
    this.registerEventListeners()
  }

  registerEventListeners(): void {
    this.win.addEventListener("load", this.onLoad.bind(this))
  }

  /**
   * Called when window finishes loading
   *
   * @memberof __component_name__
   */
  onLoad(): void { }

  /**
   * Example of function that sends data to Swift
   *
   * @memberof __component_name__
   */
  sendBounds() {
    let sizing: BeamEmbedContentSize = {
      width: 10,
      height: 10
    }
    this.ui.sendContentSize(sizing)
  }

  toString(): string {
    return this.constructor.name
  }
}
