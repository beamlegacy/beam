import { BeamCoordinates, BeamElement, BeamHTMLElement, BeamMouseLocation, BeamNode, BeamRange, BeamRangeGroup, BeamSelection, BeamShootGroup, BeamWindow } from "@beam/native-beamtypes";
export declare class PointAndShootHelper {
    /**
     * Check if string matches any items in array of strings. For a minor performance
     * improvement we check first if the string is a single character.
     *
     * @static
     * @param {string} text
     * @return {*}  {boolean} true if text matches
     * @memberof PointAndShootHelper
     */
    static isOnlyMarkupChar(text: string): boolean;
    /**
     * Returns whether or not a text is deemed useful enough as a single unit
     * we should be very cautious with what we filter out, so instead of relying
     * on the text length > 1 char we're just having a blacklist of characters
     *
     * @param text
     */
    static isTextMeaningful(text: string): boolean;
    /**
     * Checks if an element meets the requirements to be considered meaningful
     * to be included within the highlighted area. An element is meaningful if
     * it's visible and if it's either an image or it has at least some actual
     * text content
     *
     * @param element
     * @param win
     */
    static isMeaningful(element: BeamElement, win: BeamWindow): boolean;
    /**
     * Returns true if element matches a known html to ignore on specific urls.
     *
     * @static
     * @param {BeamElement} element
     * @param {BeamWindow} win
     * @return {*}  {boolean} true if element should be ignored
     * @memberof PointAndShootHelper
     */
    static isUselessSiteSpecificElement(element: BeamElement, win: BeamWindow): boolean;
    /**
     * Recursively check for the presence of any meaningful child nodes within a given element
     *
     * @static
     * @param {BeamElement} element The Element to query
     * @param {BeamWindow} win
     * @return {*}  {boolean} Boolean if element or any of it's children are meaningful
     * @memberof PointAndShootHelper
     */
    static isMeaningfulOrChildrenAre(element: BeamElement, win: BeamWindow): boolean;
    /**
     * Recursively check for the presence of any meaningful child nodes within a given element.
     *
     * @static
     * @param {BeamElement} element The Element to query
     * @param {BeamWindow} win
     * @return {*}  {BeamNode[]} return the element's meaningful child nodes
     * @memberof PointAndShootHelper
     */
    static getMeaningfulChildNodes(element: BeamElement, win: BeamWindow): BeamNode[];
    /**
     * Recursively check for the presence of any Useless child nodes within a given element
     *
     * @static
     * @param {BeamElement} element The Element to query
     * @param {BeamWindow} win
     * @return {*}  {boolean} Boolean if element or any of it's children are Useless
     * @memberof PointAndShootHelper
     */
    static isUselessOrChildrenAre(element: BeamElement, win: BeamWindow): boolean;
    /**
     * Get all child nodes of type element or text
     *
     * @static
     * @param {BeamElement} element
     * @param {BeamWindow} win
     * @return {*}  {BeamNode[]}
     * @memberof PointAndShootHelper
     */
    static getElementAndTextChildNodesRecursively(element: BeamElement, win: BeamWindow): BeamNode[];
    /**
     * Returns true if only the altKey is pressed. Alt is equal to Option is MacOS.
     *
     * @static
     * @param {*} ev
     * @return {*}  {boolean}
     * @memberof PointAndShootHelper
     */
    static isOnlyAltKey(ev: any): boolean;
    static upsertShootGroup(newItem: BeamShootGroup, groups: BeamShootGroup[]): void;
    static upsertRangeGroup(newItem: BeamRangeGroup, groups: BeamRangeGroup[]): void;
    /**
     * Returns true when the target has `contenteditable="true"` or `contenteditable="plaintext-only"`
     *
     * @static
     * @param {BeamHTMLElement} target
     * @return {*}  {boolean}
     * @memberof PointAndShootHelper
     */
    static isExplicitlyContentEditable(target: BeamHTMLElement): boolean;
    /**
     * Check for inherited contenteditable attribute value by traversing
     * the ancestors until an explicitly set value is found
     *
     * @param element {(BeamNode)} The DOM node to check.
     * @return If the element inherits from an actual contenteditable valid values
     *         ("true", "plaintext-only")
     */
    static getInheritedContentEditable(element: BeamHTMLElement): boolean;
    /**
     * Returns true when target is a text input. Specificly when either of these conditions is true:
     *  - The target is an text <input> tag
     *  - The target or it's parent element is contentEditable
     *
     * @static
     * @param {BeamHTMLElement} target
     * @return {*}  {boolean}
     * @memberof PointAndShootHelper
     */
    static isTargetTextualInput(target: BeamHTMLElement): boolean;
    /**
     * Returns true when the Target element is the activeElement. It always returns false when the target Element is the document body.
     *
     * @static
     * @param {BeamWindow} win
     * @param {BeamHTMLElement} target
     * @return {*}  {boolean}
     * @memberof PointAndShootHelper
     */
    static isEventTargetActive(win: BeamWindow, target: BeamHTMLElement): boolean;
    /**
     * Returns true when the Target Text Element is the activeElement (The current element with "Focus")
     *
     * @static
     * @param {BeamWindow} win
     * @param {BeamHTMLElement} target
     * @return {*}  {boolean}
     * @memberof PointAndShootHelper
     */
    static isActiveTextualInput(win: BeamWindow, target: BeamHTMLElement): boolean;
    /**
     * Checks if the MouseLocation Coordinates has changed from the provided X or Y Coordinates. Returns true when either X or Y is different
     *
     * @static
     * @param {BeamMouseLocation} mouseLocation
     * @param {number} clientX
     * @param {number} clientY
     * @return {*}  {boolean}
     * @memberof PointAndShootHelper
     */
    static hasMouseLocationChanged(mouseLocation: BeamMouseLocation, clientX: number, clientY: number): boolean;
    /**
     * Returns true when the current document has an Text Input or ContentEditable element as activeElement (The current element with "Focus")
     *
     * @static
     * @param {BeamWindow} win
     * @return {*}  {boolean}
     * @memberof PointAndShootHelper
     */
    static hasFocusedTextualInput(win: BeamWindow): boolean;
    /**
     * Returns true when Pointing should be disabled. It checks if any of the following is true:
     *  - The event is on an active Text Input
     *  - The document has a focussed Text Input
     *  - The document has an active Text Selection
     *
     * @static
     * @param {BeamWindow} win
     * @param {BeamHTMLElement} target
     * @return {*}  {boolean}
     * @memberof PointAndShootHelper
     */
    static isPointDisabled(win: BeamWindow, target: BeamHTMLElement): boolean;
    /**
     * Returns boolean if document has active selection
     */
    static hasSelection(win: BeamWindow): boolean;
    /**
     * Returns an array of ranges for a given HTML selection
     *
     * @param {BeamSelection} selection
     * @return {*}  {BeamRange[]}
     */
    static getSelectionRanges(selection: BeamSelection): BeamRange[];
    /**
     * Returns the current active (text) selection on the document
     *
     * @return {BeamSelection}
     */
    static getSelection(win: BeamWindow): BeamSelection;
    /**
     * Returns the HTML element under the current Mouse Location Coordinates
     *
     * @static
     * @param {BeamWindow} win
     * @param {BeamMouseLocation} mouseLocation
     * @return {*}  {BeamHTMLElement}
     * @memberof PointAndShootHelper
     */
    static getElementAtMouseLocation(win: BeamWindow, mouseLocation: BeamMouseLocation): BeamHTMLElement;
    static getOffset(object: BeamElement, offset: BeamCoordinates): void;
    static getScrolled(object: BeamElement, scrolled: BeamCoordinates): void;
    /**
     * Get top left X, Y coordinates of element taking into acocunt the scroll position
     *
     * @static
     * @param {BeamElement} el
     * @return {*}  {BeamCoordinates}
     * @memberof Util
     */
    static getTopLeft(el: BeamElement): BeamCoordinates;
    /**
     * Return value clamped between min and max
     *
     * @static
     * @param {number} val
     * @param {number} min
     * @param {number} max
     * @return {number}
     * @memberof Util
     */
    static clamp(val: number, min: number, max: number): number;
    /**
     * Remove null and undefined from array
     *
     * @static
     * @param {unknown[]} array
     * @return {*}  {any[]}
     * @memberof Util
     */
    static compact(array: any[]): any[];
    /**
     * Check if number is in range
     *
     * @static
     * @param {number} number The number to check.
     * @param {number} start The start of the range.
     * @param {number} end The end of the range.
     * @returns {boolean} Returns `true` if `number` is in the range, else `false`.
     * @memberof Util
     */
    static isNumberInRange(number: number, start: number, end: number): boolean;
    /**
     * Maps value, from range to range
     *
     * For example mapping 10 degrees Celcius to Fahrenheit
     * `mapRangeToRange([0, 100], [32, 212], 10)`
     *
     * @static
     * @param {[number, number]} from
     * @param {[number, number]} to
     * @param {number} s
     * @return {*}  {number}
     * @memberof Util
     */
    static mapRangeToRange(from: [number, number], to: [number, number], s: number): number;
    /**
     * Generates a good enough non-compliant UUID.
     *
     * @static
     * @param {BeamWindow} win
     * @return {*}  {string}
     * @memberof Util
     */
    static uuid(win: BeamWindow<any>): string;
    /**
     * Remove first matched item from array, Uses findIndex under the hood.
     *
     * @static
     * @param {(arrayElement) => boolean} matcher when matcher returns true that item is removed from array
     * @param {unknown[]} array input array
     * @return {*}  {unknown[]} return updated array
     * @memberof Util
     */
    static removeFromArray(matcher: (arrayElement: any) => boolean, array: unknown[]): unknown[];
}
