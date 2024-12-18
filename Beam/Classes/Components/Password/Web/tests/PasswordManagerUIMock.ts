import { EventsMock } from "@beam/native-testmocks"
import { PasswordManagerUI } from "../src/PasswordManagerUI"

export class PasswordManagerUIMock extends EventsMock implements PasswordManagerUI {
  load(url: string) {
    throw new Error("Method not implemented.")
  }
  resize(width: number, height: number): void {
    throw new Error("Method not implemented.")
  }
  textInputReceivedFocus(id: string, text: string): void {
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
