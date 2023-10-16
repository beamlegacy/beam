import { BeamWindow } from "@beam/native-beamtypes";
export declare class PasswordManagerHelper {
    win: BeamWindow;
    frameIdentifier: string;
    lastId: number;
    /**
     * @param win {(BeamWindow)}
     */
    constructor(win: BeamWindow<any>);
    /**
     * Returns true if element is a textField element
     *
     * @param {*} element
     * @return {*}  {boolean}
     * @memberof Helpers
     */
    isTextField(element: any): boolean;
    /**
     * Returns true if element has no "disabled" attribute
     *
     * @param {*} element
     * @return {*}  {boolean}
     * @memberof Helpers
     */
    isEnabled(element: any): boolean;
    /**
     * Returns new unique identifier. The identifier is unique to the
     * window frame and each time this method is called the trailing
     * number is incremented.
     *
     * @return {*}  {string}
     * @memberof Helpers
     */
    makeBeamId(): string;
    /**
     * returns true if provided element has a "data-beam-id" in
     * it's attributes.
     *
     * @param {*} element
     * @return {*}  {boolean}
     * @memberof Helpers
     */
    hasBeamId(element: any): boolean;
    /**
     * Returns the beam ID of the element. If no ID is found of the element
     * a unique ID will be created and assigned to the element attribute.
     *
     * @param {*} element
     * @return {*}  {string}
     * @memberof Helpers
     */
    getOrCreateBeamId(element: any): string;
    /**
     * Finds and returns element based on the beam ID
     *
     * @param {string} beamId
     * @return {*}  {}
     * @memberof Helpers
     */
    getElementById(beamId: string): Element;
    /**
     * Finds and returns all non-disabled text field elements in the document
     *
     * @return {*}  {Element[]}
     * @memberof Helpers
     */
    getTextFieldsInDocument(): Element[];
    getFocusedField(): string;
    getElementRects(ids_json: any): string;
    getTextFieldValues(ids_json: any): string;
    setTextFieldValues(fields_json: any): void;
    togglePasswordFieldVisibility(fields_json: any, visibility: any): void;
    setFrameIdentifier(frameIdentifier: string): void;
}
