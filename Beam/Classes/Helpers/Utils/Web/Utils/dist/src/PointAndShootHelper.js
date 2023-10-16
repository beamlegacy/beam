"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PointAndShootHelper = void 0;
const native_beamtypes_1 = require("@beam/native-beamtypes");
const BeamElementHelper_1 = require("./BeamElementHelper");
const BeamEmbedHelper_1 = require("./BeamEmbedHelper");
class PointAndShootHelper {
    /**
     * Check if string matches any items in array of strings. For a minor performance
     * improvement we check first if the string is a single character.
     *
     * @static
     * @param {string} text
     * @return {*}  {boolean} true if text matches
     * @memberof PointAndShootHelper
     */
    static isOnlyMarkupChar(text) {
        if (text.length == 1) {
            return ["•", "-", "|", "–", "—", "·"].includes(text);
        }
        else {
            return false;
        }
    }
    /**
     * Returns whether or not a text is deemed useful enough as a single unit
     * we should be very cautious with what we filter out, so instead of relying
     * on the text length > 1 char we're just having a blacklist of characters
     *
     * @param text
     */
    static isTextMeaningful(text) {
        if (text) {
            const trimmed = text.trim();
            return !!trimmed && !this.isOnlyMarkupChar(trimmed);
        }
        return false;
    }
    /**
     * Checks if an element meets the requirements to be considered meaningful
     * to be included within the highlighted area. An element is meaningful if
     * it's visible and if it's either an image or it has at least some actual
     * text content
     *
     * @param element
     * @param win
     */
    static isMeaningful(element, win) {
        const embedHelper = new BeamEmbedHelper_1.BeamEmbedHelper(win);
        return ((embedHelper.isEmbeddableElement(element) ||
            BeamElementHelper_1.BeamElementHelper.isMedia(element) ||
            BeamElementHelper_1.BeamElementHelper.isImageContainer(element, win) ||
            PointAndShootHelper.isTextMeaningful(BeamElementHelper_1.BeamElementHelper.getTextValue(element))) &&
            BeamElementHelper_1.BeamElementHelper.isVisible(element, win));
    }
    /**
     * Returns true if element matches a known html to ignore on specific urls.
     *
     * @static
     * @param {BeamElement} element
     * @param {BeamWindow} win
     * @return {*}  {boolean} true if element should be ignored
     * @memberof PointAndShootHelper
     */
    static isUselessSiteSpecificElement(element, win) {
        var _a;
        // Amazon Magnifier
        if (((_a = win.location.hostname) === null || _a === void 0 ? void 0 : _a.includes("amazon.")) && element.id == "magnifierLens") {
            return true;
        }
        return false;
    }
    /**
     * Recursively check for the presence of any meaningful child nodes within a given element
     *
     * @static
     * @param {BeamElement} element The Element to query
     * @param {BeamWindow} win
     * @return {*}  {boolean} Boolean if element or any of it's children are meaningful
     * @memberof PointAndShootHelper
     */
    static isMeaningfulOrChildrenAre(element, win) {
        if (PointAndShootHelper.isMeaningful(element, win)) {
            return true;
        }
        return [...element.children].some((child) => PointAndShootHelper.isMeaningful(child, win));
    }
    /**
     * Recursively check for the presence of any meaningful child nodes within a given element.
     *
     * @static
     * @param {BeamElement} element The Element to query
     * @param {BeamWindow} win
     * @return {*}  {BeamNode[]} return the element's meaningful child nodes
     * @memberof PointAndShootHelper
     */
    static getMeaningfulChildNodes(element, win) {
        return [...element.childNodes].filter((child) => (child.nodeType === native_beamtypes_1.BeamNodeType.element &&
            PointAndShootHelper.isMeaningfulOrChildrenAre(child, win)) ||
            (child.nodeType === native_beamtypes_1.BeamNodeType.text && PointAndShootHelper.isTextMeaningful(child.data)));
    }
    /**
     * Recursively check for the presence of any Useless child nodes within a given element
     *
     * @static
     * @param {BeamElement} element The Element to query
     * @param {BeamWindow} win
     * @return {*}  {boolean} Boolean if element or any of it's children are Useless
     * @memberof PointAndShootHelper
     */
    static isUselessOrChildrenAre(element, win) {
        return PointAndShootHelper.isMeaningfulOrChildrenAre(element, win) == false;
    }
    /**
     * Get all child nodes of type element or text
     *
     * @static
     * @param {BeamElement} element
     * @param {BeamWindow} win
     * @return {*}  {BeamNode[]}
     * @memberof PointAndShootHelper
     */
    static getElementAndTextChildNodesRecursively(element, win) {
        if (!(element === null || element === void 0 ? void 0 : element.childNodes)) {
            return [element];
        }
        const nodes = [];
        [...element.childNodes].forEach((child) => {
            switch (child.nodeType) {
                case native_beamtypes_1.BeamNodeType.element:
                    nodes.push(child);
                    // eslint-disable-next-line no-case-declarations
                    const childNodesOfChild = this.getElementAndTextChildNodesRecursively(child, win);
                    nodes.push(...childNodesOfChild);
                    break;
                case native_beamtypes_1.BeamNodeType.text:
                    nodes.push(child);
                    break;
                default:
                    break;
            }
        });
        if (nodes.length == 0) {
            return [element];
        }
        return nodes;
    }
    /**
     * Returns true if only the altKey is pressed. Alt is equal to Option is MacOS.
     *
     * @static
     * @param {*} ev
     * @return {*}  {boolean}
     * @memberof PointAndShootHelper
     */
    static isOnlyAltKey(ev) {
        const altKey = ev.altKey || ev.key == "Alt";
        return altKey && !ev.ctrlKey && !ev.metaKey && !ev.shiftKey;
    }
    static upsertShootGroup(newItem, groups) {
        // Update existing rangeGroup
        const index = groups.findIndex(({ element }) => {
            return element == newItem.element;
        });
        if (index != -1) {
            groups[index] = newItem;
        }
        else {
            groups.push(newItem);
        }
    }
    static upsertRangeGroup(newItem, groups) {
        // Update existing rangeGroup
        const index = groups.findIndex(({ id }) => {
            return id == newItem.id;
        });
        if (index != -1) {
            groups[index] = newItem;
        }
        else {
            groups.push(newItem);
        }
    }
    /**
     * Returns true when the target has `contenteditable="true"` or `contenteditable="plaintext-only"`
     *
     * @static
     * @param {BeamHTMLElement} target
     * @return {*}  {boolean}
     * @memberof PointAndShootHelper
     */
    static isExplicitlyContentEditable(target) {
        return ["true", "plaintext-only"].includes(BeamElementHelper_1.BeamElementHelper.getContentEditable(target));
    }
    /**
     * Check for inherited contenteditable attribute value by traversing
     * the ancestors until an explicitly set value is found
     *
     * @param element {(BeamNode)} The DOM node to check.
     * @return If the element inherits from an actual contenteditable valid values
     *         ("true", "plaintext-only")
     */
    static getInheritedContentEditable(element) {
        let isEditable = this.isExplicitlyContentEditable(element);
        const parent = element.parentElement;
        if (parent && BeamElementHelper_1.BeamElementHelper.getContentEditable(element) === "inherit") {
            isEditable = this.getInheritedContentEditable(parent);
        }
        return isEditable;
    }
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
    static isTargetTextualInput(target) {
        return BeamElementHelper_1.BeamElementHelper.isTextualInputType(target) || this.getInheritedContentEditable(target);
    }
    /**
     * Returns true when the Target element is the activeElement. It always returns false when the target Element is the document body.
     *
     * @static
     * @param {BeamWindow} win
     * @param {BeamHTMLElement} target
     * @return {*}  {boolean}
     * @memberof PointAndShootHelper
     */
    static isEventTargetActive(win, target) {
        return !!(win.document.activeElement &&
            win.document.activeElement !== win.document.body &&
            win.document.activeElement.contains(target));
    }
    /**
     * Returns true when the Target Text Element is the activeElement (The current element with "Focus")
     *
     * @static
     * @param {BeamWindow} win
     * @param {BeamHTMLElement} target
     * @return {*}  {boolean}
     * @memberof PointAndShootHelper
     */
    static isActiveTextualInput(win, target) {
        return this.isEventTargetActive(win, target) && this.isTargetTextualInput(target);
    }
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
    static hasMouseLocationChanged(mouseLocation, clientX, clientY) {
        return (mouseLocation === null || mouseLocation === void 0 ? void 0 : mouseLocation.x) !== clientX || (mouseLocation === null || mouseLocation === void 0 ? void 0 : mouseLocation.y) !== clientY;
    }
    /**
     * Returns true when the current document has an Text Input or ContentEditable element as activeElement (The current element with "Focus")
     *
     * @static
     * @param {BeamWindow} win
     * @return {*}  {boolean}
     * @memberof PointAndShootHelper
     */
    static hasFocusedTextualInput(win) {
        const target = win.document.activeElement;
        if (target) {
            return BeamElementHelper_1.BeamElementHelper.isTextualInputType(target) || this.getInheritedContentEditable(target);
        }
        else {
            return false;
        }
    }
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
    static isPointDisabled(win, target) {
        return this.isActiveTextualInput(win, target) || this.hasFocusedTextualInput(win) || this.hasSelection(win);
    }
    /**
     * Returns boolean if document has active selection
     */
    static hasSelection(win) {
        return !win.document.getSelection().isCollapsed && Boolean(win.document.getSelection().toString());
    }
    /**
     * Returns an array of ranges for a given HTML selection
     *
     * @param {BeamSelection} selection
     * @return {*}  {BeamRange[]}
     */
    static getSelectionRanges(selection) {
        const ranges = [];
        const count = selection.rangeCount;
        for (let index = 0; index < count; ++index) {
            const range = selection.getRangeAt(index);
            ranges.push(range);
        }
        return ranges;
    }
    /**
     * Returns the current active (text) selection on the document
     *
     * @return {BeamSelection}
     */
    static getSelection(win) {
        return win.document.getSelection();
    }
    /**
     * Returns the HTML element under the current Mouse Location Coordinates
     *
     * @static
     * @param {BeamWindow} win
     * @param {BeamMouseLocation} mouseLocation
     * @return {*}  {BeamHTMLElement}
     * @memberof PointAndShootHelper
     */
    static getElementAtMouseLocation(win, mouseLocation) {
        return win.document.elementFromPoint(mouseLocation.x, mouseLocation.y);
    }
    static getOffset(object, offset) {
        if (object) {
            offset.x += object.offsetLeft;
            offset.y += object.offsetTop;
            PointAndShootHelper.getOffset(object.offsetParent, offset);
        }
    }
    static getScrolled(object, scrolled) {
        if (object) {
            scrolled.x += object.scrollLeft;
            scrolled.y += object.scrollTop;
            if (object.tagName.toLowerCase() != "html") {
                PointAndShootHelper.getScrolled(object.parentNode, scrolled);
            }
        }
    }
    /**
     * Get top left X, Y coordinates of element taking into acocunt the scroll position
     *
     * @static
     * @param {BeamElement} el
     * @return {*}  {BeamCoordinates}
     * @memberof Util
     */
    static getTopLeft(el) {
        const offset = { x: 0, y: 0 };
        PointAndShootHelper.getOffset(el, offset);
        const scrolled = { x: 0, y: 0 };
        PointAndShootHelper.getScrolled(el.parentNode, scrolled);
        const x = offset.x - scrolled.x;
        const y = offset.y - scrolled.y;
        return { x, y };
    }
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
    static clamp(val, min, max) {
        return val > max ? max : val < min ? min : val;
    }
    /**
     * Remove null and undefined from array
     *
     * @static
     * @param {unknown[]} array
     * @return {*}  {any[]}
     * @memberof Util
     */
    static compact(array) {
        return array.filter((item) => {
            return item != null;
        });
    }
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
    static isNumberInRange(number, start, end) {
        return Number(number) >= Math.min(start, end) && number <= Math.max(start, end);
    }
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
    static mapRangeToRange(from, to, s) {
        return to[0] + ((s - from[0]) * (to[1] - to[0])) / (from[1] - from[0]);
    }
    /**
     * Generates a good enough non-compliant UUID.
     *
     * @static
     * @param {BeamWindow} win
     * @return {*}  {string}
     * @memberof Util
     */
    static uuid(win) {
        const buf = new Uint32Array(4);
        return win.crypto.getRandomValues(buf).join("-");
    }
    /**
     * Remove first matched item from array, Uses findIndex under the hood.
     *
     * @static
     * @param {(arrayElement) => boolean} matcher when matcher returns true that item is removed from array
     * @param {unknown[]} array input array
     * @return {*}  {unknown[]} return updated array
     * @memberof Util
     */
    static removeFromArray(matcher, array) {
        const foundIndex = array.findIndex(matcher);
        // foundIndex is -1 when no match is found. Only remove found items from array
        if (foundIndex >= 0) {
            array.splice(foundIndex, 1);
        }
        return array;
    }
}
exports.PointAndShootHelper = PointAndShootHelper;
//# sourceMappingURL=PointAndShootHelper.js.map