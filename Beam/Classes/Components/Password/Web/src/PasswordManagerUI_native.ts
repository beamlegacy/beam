import {
  BeamLogCategory,
  BeamWindow,
  Native
} from "@beam/native-beamtypes"
import { BeamLogger } from "@beam/native-utils"
import { PasswordManagerUI } from "./PasswordManagerUI"

export class PasswordManagerUI_native implements PasswordManagerUI {
  logger: BeamLogger
  /**
   * @param native {Native}
   */
  constructor(protected native: Native<any>) {
    this.logger = new BeamLogger(this.native.win, BeamLogCategory.passwordManagerInternal)
    this.logger.log(`${this.toString()} instantiated`)
  }

  /**
   *
   * @param win {BeamWindow}
   * @returns {PasswordManagerUI_native}
   */
  static getInstance(win: BeamWindow): PasswordManagerUI_native {
    let instance
    try {
      const native = Native.getInstance(win, "PasswordManager")
      instance = new PasswordManagerUI_native(native)
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(e)
      instance = null
    }
    return instance
  }

  load(url: string) {
      this.native.sendMessage("loaded", { url })
  }

  resize(width: number, height: number) {
    this.native.sendMessage("resize", { width, height })
  }

  textInputReceivedFocus(id: string, text: string): void {
    this.native.sendMessage("textInputFocusIn", { id, text })
  }

  textInputLostFocus(id: string): void {
    this.native.sendMessage("textInputFocusOut", { id })
  }

  formSubmit(id: string): void {
    this.native.sendMessage("formSubmit", { id })
  }

  sendTextFields(textFieldsString: string): void {
      this.native.sendMessage("textInputFields", {textFieldsString})
  }

  toString(): string {
    return this.constructor.name
  }
}
