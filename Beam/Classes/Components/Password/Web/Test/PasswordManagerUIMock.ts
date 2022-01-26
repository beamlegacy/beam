import { EventsMock } from "../../../../Helpers/Utils/Web/Test/Mock/EventsMock"
import { PasswordScrollInfo } from "../PasswordManagerTypes"
import { PasswordManagerUI } from "../PasswordManagerUI"

export class PasswordManagerUIMock extends EventsMock implements PasswordManagerUI {
  load(url: string) {
    throw new Error("Method not implemented.")
  }
  resize(width: number, height: number): void {
    throw new Error("Method not implemented.")
  }
  scroll(scrollInfo: PasswordScrollInfo): void {
    throw new Error("Method not implemented.")
  }
  textInputRecievedFocus(id: string, text: string): void {
    throw new Error("Method not implemented.")
  }
  textInputLostFocus(id: string): void {
    throw new Error("Method not implemented.")
  }
  formSubmit(id: string): void {
    throw new Error("Method not implemented.")
  }
  sendTextFields(textFieldsString: string): void {
    throw new Error("Method not implemented.")
  }

}
