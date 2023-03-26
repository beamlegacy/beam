import { BeamWindow, Native } from "@beam/native-beamtypes";
import { BeamLogger } from "@beam/native-utils";
import { PasswordManagerUI } from "./PasswordManagerUI";
export declare class PasswordManagerUI_native implements PasswordManagerUI {
    protected native: Native<any>;
    logger: BeamLogger;
    /**
     * @param native {Native}
     */
    constructor(native: Native<any>);
    /**
     *
     * @param win {BeamWindow}
     * @returns {PasswordManagerUI_native}
     */
    static getInstance(win: BeamWindow): PasswordManagerUI_native;
    load(url: string): void;
    resize(width: number, height: number): void;
    textInputReceivedFocus(id: string, text: string): void;
    textInputLostFocus(id: string): void;
    formSubmit(id: string): void;
    sendTextFields(textFieldsString: string): void;
    toString(): string;
}
