export interface PasswordManagerUI {
    load(url: string): any;
    resize(width: number, height: number): void;
    textInputReceivedFocus(id: string, text: string): void;
    textInputLostFocus(id: string): void;
    formSubmit(id: string): void;
    sendTextFields(textFieldsString: string): void;
}
