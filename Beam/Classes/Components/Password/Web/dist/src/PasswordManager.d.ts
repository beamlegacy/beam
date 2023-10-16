import { BeamWindow, BeamUIEvent } from "@beam/native-beamtypes";
import { BeamLogger } from "@beam/native-utils";
import { PasswordManagerUI } from "./PasswordManagerUI";
import { PasswordManagerHelper } from "./PasswordManagerHelper";
export declare class PasswordManager<UI extends PasswordManagerUI> {
    protected ui: UI;
    win: BeamWindow;
    logger: BeamLogger;
    passwordHelper: PasswordManagerHelper;
    /**
     * Singleton
     *
     * @type PasswordManager
     */
    static instance: PasswordManager<any>;
    /**
     * @param win {(BeamWindow)}
     * @param ui {PasswordManagerUI}
     */
    constructor(win: BeamWindow<any>, ui: UI);
    textFields: any[];
    onLoad(): void;
    /**
     * Installs window resize eventlistener and installs focus
     * and focusout eventlisteners on each element from the provided ids
     *
     * @param {string} ids_json
     * @memberof PasswordManager
     */
    installFocusHandlers(ids_json: string): void;
    resize(event: BeamUIEvent): void;
    elementDidGainFocus(event: BeamUIEvent): void;
    elementDidLoseFocus(event: BeamUIEvent): void;
    /**
     * Installs eventhandler for submit events on form elements
     *
     * @memberof PasswordManager
     */
    installSubmitHandler(): void;
    postSubmitMessage(event: any): void;
    sendTextFields(frameIdentifier: any): void;
    setupObserver(): void;
    handleTextFields(): void;
    toString(): string;
}
