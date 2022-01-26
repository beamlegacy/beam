// import {  } from "../../../Helpers/Utils/Web/BeamTypes"

import { PasswordScrollInfo } from "./PasswordManagerTypes";

export interface PasswordManagerUI {
  load(url: string);
  resize(width: number, height: number): void
  scroll(scrollInfo: PasswordScrollInfo): void
  textInputRecievedFocus(id: string, text: string): void
  textInputLostFocus(id: string): void
  formSubmit(id: string): void
  sendTextFields(textFieldsString: string): void
}
