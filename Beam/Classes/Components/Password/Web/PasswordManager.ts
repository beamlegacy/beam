import {
  BeamLogCategory,
  BeamWindow
} from "../../../Helpers/Utils/Web/BeamTypes"
import { BeamUIEvent } from "../../../Helpers/Utils/Web/BeamUIEvent"
import { BeamLogger } from "../../../Helpers/Utils/Web/BeamLogger"
import { PasswordManagerUI } from "./PasswordManagerUI"
import { PasswordManagerHelper } from "./PasswordManagerHelper"
import {dequal as isDeepEqual} from "dequal"

export class PasswordManager<UI extends PasswordManagerUI> {
  win: BeamWindow
  logger: BeamLogger
  passwordHelper: PasswordManagerHelper

  /**
   * Singleton
   *
   * @type PasswordManager
   */
  static instance: PasswordManager<any>

  /**
   * @param win {(BeamWindow)}
   * @param ui {PasswordManagerUI}
   */
  constructor(win: BeamWindow<any>, protected ui: UI) {
    this.win = win
    this.logger = new BeamLogger(win, BeamLogCategory.passwordManagerInternal)
    this.passwordHelper = new PasswordManagerHelper()
    this.win.addEventListener("load", this.onLoad.bind(this))
  }

  textFields = []

  onLoad(): void {
    this.ui.load(document.URL)
  }

  /**
   * Installs window resize eventlistener and installs focus
   * and focusout eventlisteners on each element from the provided ids
   *
   * @param {string} ids_json
   * @memberof PasswordManager
   */
  installFocusHandlers(ids_json: string): void {
    const ids = JSON.parse(ids_json)
    for (const id of ids) {
      // install handlers to all inputs
      const element = this.passwordHelper.getElementById(id)
      if (element) {
        element.addEventListener("focus", this.elementDidGainFocus.bind(this), false)
        element.addEventListener("focusout", this.elementDidLoseFocus.bind(this), false)
      }
    }

    this.win.addEventListener("resize", this.resize.bind(this))
  }

  resize(event: BeamUIEvent): void {
    // eslint-disable-next-line no-console
    console.log("resize!")
    if (event.target !== null) {
      this.ui.resize(this.win.innerWidth, this.win.innerHeight)
    }
  }

  elementDidGainFocus(event: BeamUIEvent): void {
    if (event.target !== null && this.passwordHelper.isTextField(event.target)) {
      const beamId = this.passwordHelper.getOrCreateBeamId(event.target)
      const text = event.target.value
      this.ui.textInputReceivedFocus(beamId, text)
    }
  }

  elementDidLoseFocus(event: BeamUIEvent): void {
    if (event.target !== null && this.passwordHelper.isTextField(event.target)) {
      const beamId = this.passwordHelper.getOrCreateBeamId(event.target)
      this.ui.textInputLostFocus(beamId)
    }
  }

  /**
   * Installs eventhandler for submit events on form elements
   *
   * @memberof PasswordManager
   */
  installSubmitHandler(): void {
    const forms = document.getElementsByTagName("form")
    for (let e = 0; e < forms.length; e++) {
      const form = forms.item(e)
      form.addEventListener("submit", this.postSubmitMessage.bind(this))
    }
  }

  postSubmitMessage(event): void {
    const beamId = this.passwordHelper.getOrCreateBeamId(event.target)
    this.ui.formSubmit(beamId)
  }

  sendTextFields(frameIdentifier) {
    this.passwordHelper.setFrameIdentifier(frameIdentifier)
    this.setupObserver()
    this.handleTextFields()
  }

  setupObserver() {
    const observer = new MutationObserver(this.handleTextFields.bind(this))
    observer.observe(document, { childList: true, subtree: true })
  }

  handleTextFields() {
    const textFields = this.passwordHelper.getTextFieldsInDocument()
    if (!isDeepEqual(textFields, this.textFields)) {
      this.textFields = textFields
      const textFieldsString = JSON.stringify(textFields)
      this.ui.sendTextFields(textFieldsString)
    }
  }

  toString(): string {
    return this.constructor.name
  }
}
