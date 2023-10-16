"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BeamElementHelper = void 0;
const BeamRectHelper_1 = require("./BeamRectHelper");
const BeamEmbedHelper_1 = require("./BeamEmbedHelper");
/**
 * Useful methods for HTML Elements
 */
class BeamElementHelper {
    static getAttribute(attr, element) {
        const attribute = element.attributes.getNamedItem(attr);
        return attribute === null || attribute === void 0 ? void 0 : attribute.value;
    }
    static getType(element) {
        return BeamElementHelper.getAttribute("type", element);
    }
    static getContentEditable(element) {
        return BeamElementHelper.getAttribute("contenteditable", element) || "inherit";
    }
    /**
     * Returns if an element is a textarea or an input elements with a text
     * based input type (text, email, date, number...)
     *
     * @param element {BeamHTMLElement} The DOM Element to check.
     * @return If the element is some kind of text input.
     */
    static isTextualInputType(element) {
        const tag = element.tagName.toLowerCase();
        if (tag === "textarea") {
            return true;
        }
        else if (tag === "input") {
            const types = [
                "text", "email", "password",
                "date", "datetime-local", "month",
                "number", "search", "tel",
                "time", "url", "week",
                // for legacy support
                "datetime"
            ];
            return types.includes(element.type);
        }
        return false;
    }
    /**
     * Returns the text value for a given element, text value meaning either
     * the element's innerText or the input value
     *
     * @param el
     */
    static getTextValue(el) {
        let textValue;
        const tagName = el.tagName.toLowerCase();
        switch (tagName) {
            case "input":
                {
                    const inputEl = el;
                    if (BeamElementHelper.isTextualInputType(inputEl)) {
                        textValue = inputEl.value;
                    }
                }
                break;
            case "textarea":
                textValue = el.value;
                break;
            default:
                textValue = el.innerText;
        }
        return textValue;
    }
    static getBackgroundImageURL(element, win) {
        var _a;
        const style = (_a = win.getComputedStyle) === null || _a === void 0 ? void 0 : _a.call(win, element);
        const matchArray = style === null || style === void 0 ? void 0 : style.backgroundImage.match(/url\(([^)]+)/);
        if (matchArray && matchArray.length > 1) {
            return matchArray[1].replace(/('|")/g, "");
        }
    }
    /**
     * Returns parent of node type. Maximum allowed recursive depth is 10
     *
     * @static
     * @param {BeamElement} node target node to start at
     * @param {string} type parent type to search for
     * @param {number} [count=10] maximum depth of recursion, defaults to 10
     * @return {*}  {(BeamElement | undefined)}
     * @memberof BeamElementHelper
     */
    static hasParentOfType(element, type, count = 10) {
        if (count <= 0)
            return null;
        if (type !== "BODY" && (element === null || element === void 0 ? void 0 : element.tagName) === "BODY")
            return null;
        if (!(element === null || element === void 0 ? void 0 : element.parentElement))
            return null;
        if (type === (element === null || element === void 0 ? void 0 : element.tagName))
            return element;
        const newCount = count--;
        return BeamElementHelper.hasParentOfType(element.parentElement, type, newCount);
    }
    /**
     * Parse Element based on it's styles and structure. Included conversions:
     * - Convert background image element to img element
     * - Wrapping element in anchor if parent is anchor tag
     *
     * @static
     * @param {BeamElement} element
     * @param {BeamWindow<any>} win
     * @return {*}  {BeamHTMLElement}
     * @memberof BeamElementHelper
     */
    static parseElementBasedOnStyles(element, win) {
        const embedHelper = new BeamEmbedHelper_1.BeamEmbedHelper(win);
        // If we support embedding on the current location
        if (embedHelper.isEmbeddableElement(element)) {
            // parse the element for embedding.
            const embedElement = embedHelper.parseElementForEmbed(element);
            if (embedElement) {
                console.log("isEmbeddable");
                return embedElement;
            }
        }
        return element;
    }
    /**
     * Determine whether or not an element is visible based on it's style
     * and bounding box if necessary
     *
     * @param element: {BeamElement}
     * @param win: {BeamWindow}
     * @return If the element is considered visible
     */
    // is slow, propertyvalue and boundingrect
    static isVisible(element, win) {
        var _a;
        let visible = false;
        if (element) {
            visible = true;
            // We start by getting the element's computed style to check for any smoking guns
            const style = (_a = win.getComputedStyle) === null || _a === void 0 ? void 0 : _a.call(win, element);
            if (style) {
                visible = !(style.getPropertyValue("display") === "none"
                    // Maybe hidden shouldn't be filtered out see the opacity comment
                    || ["hidden", "collapse"].includes(style.getPropertyValue("visibility"))
                    // The following heuristic isn't enough: twitter uses transparent inputs on top of their custom UI
                    // (see theme selector in display settings for an example)
                    // || style.opacity === '0'
                    || (style.getPropertyValue("width") === "1px" && style.getPropertyValue("height") === "1px")
                    || ["0px", "0"].includes(style.getPropertyValue("width"))
                    || ["0px", "0"].includes(style.getPropertyValue("height"))
                    // many clipPath values could cause the element to not be visible, but for now we only deal with single % values
                    || (style.getPropertyValue("position") === "absolute"
                        && style.getPropertyValue("clip").match(/rect\((0(px)?[, ]+){3}0px\)/))
                    || style.getPropertyValue("clip-path").match(/inset\(([5-9]\d|100)%\)/));
            }
            // Still visible? Use boundingClientRect as a final check, it's expensive
            // so we should strive no to call it if it's unnecessary
            if (visible) {
                const rect = element.getBoundingClientRect();
                visible = (rect.width > 0 && rect.height > 0);
            }
        }
        return visible;
    }
    /**
     * Returns whether an element is either a video or an audio element
     *
     * @param element
     */
    static isMedia(element) {
        return (["video", "audio"].includes(element.tagName.toLowerCase()) ||
            Boolean(element.querySelectorAll("video, audio").length));
    }
    /**
     * Check whether an element is an image, or has a background-image url
     * the background image can be a data:uri. Or has any child that is a img or svg.
     *
     * @param element
     * @param win
     * @return If the element is considered visible
     */
    static isImageOrContainsImageChild(element, win) {
        const matcher = (element) => (["img", "svg"].includes(element.tagName.toLowerCase())
            || Boolean(element.querySelectorAll("img, svg").length));
        return BeamElementHelper.isImage(element, win, matcher);
    }
    /**
     * Check whether an element is an image, or has a background-image url
     * the background image can be a data:uri
     *
     * @param element
     * @param win
     * @return If the element is considered visible
     */
    static isImage(element, win, matcher = BeamElementHelper.imageElementMatcher) {
        var _a;
        // currentSrc vs src
        if (matcher(element)) {
            return true;
        }
        const style = (_a = win.getComputedStyle) === null || _a === void 0 ? void 0 : _a.call(win, element);
        const match = style === null || style === void 0 ? void 0 : style.backgroundImage.match(/url\(([^)]+)/);
        return !!match;
    }
    /**
     * Returns whether an element is an image container, which means it can be an image
     * itself or recursively contain only image containers
     *
     * @param element
     * @param win
     */
    static isImageContainer(element, win) {
        if (BeamElementHelper.isImage(element, win)) {
            return true;
        }
        if (element.children.length > 0) {
            return [...element.children].every(child => BeamElementHelper.isImageContainer(child, win));
        }
        return false;
    }
    /**
     * Returns the root svg element for the given element if any
     * @param element
     */
    static getSvgRoot(element) {
        if (["body", "html"].includes(element.tagName.toLowerCase())) {
            return;
        }
        if (element.tagName.toLowerCase() === "svg") {
            return element;
        }
        if (element.parentElement) {
            return BeamElementHelper.getSvgRoot(element.parentElement);
        }
    }
    /**
     * Returns the first positioned element out of the element itself and its ancestors
     *
     * @param element
     * @param win
     */
    static getPositionedElement(element, win) {
        var _a;
        // Ignore body
        if (!element || element === win.document.body) {
            return;
        }
        const style = (_a = win.getComputedStyle) === null || _a === void 0 ? void 0 : _a.call(win, element);
        if (element.parentElement && (style === null || style === void 0 ? void 0 : style.position) === "static") {
            return BeamElementHelper.getPositionedElement(element.parentElement, win);
        }
        if ((style === null || style === void 0 ? void 0 : style.position) !== "static") {
            return element;
        }
    }
    /**
     * Return the first overflow escaping element. Since css overflow can be escaped by positioning
     * an element relative to the viewport, either by using `fixed`, or `absolute` in the case
     * there's no other positioning context
     *
     * @param element
     * @param clippingContainer
     * @param win
     */
    static getOverflowEscapingElement(element, clippingContainer, win) {
        var _a;
        // Ignore body
        if (!element || element === win.document.body) {
            return;
        }
        const style = (_a = win.getComputedStyle) === null || _a === void 0 ? void 0 : _a.call(win, element);
        if (style) {
            switch (style.position) {
                case "absolute": {
                    // If absolute, we need to make sure it's not within a positioned element already
                    const positionedAncestor = BeamElementHelper.getPositionedElement(element.parentElement, win);
                    if (positionedAncestor && positionedAncestor.contains(clippingContainer)) {
                        return element;
                    }
                    return element;
                }
                case "fixed":
                    // Fixed elements always escape overflow clipping
                    return element;
                default:
                    return BeamElementHelper.getOverflowEscapingElement(element.parentElement, clippingContainer, win);
            }
        }
    }
    /**
     * Recursively look for the first ancestor element with an `overflow`, `clip`, or `clip-path
     * css property triggering clipping on the element
     *
     * @param element
     * @param win
     */
    static getClippingElement(element, win) {
        var _a;
        // Ignore body
        if (element === win.document.body) {
            return;
        }
        const style = (_a = win.getComputedStyle) === null || _a === void 0 ? void 0 : _a.call(win, element);
        if (style) {
            if (style.getPropertyValue("overflow") === "visible"
                && style.getPropertyValue("overflow-x") === "visible"
                && style.getPropertyValue("overflow-y") === "visible"
                && style.getPropertyValue("clip") === "auto"
                && style.getPropertyValue("clip-path") === "none") {
                if (element.parentElement) {
                    return BeamElementHelper.getClippingElement(element.parentElement, win);
                }
            }
            else {
                return element;
            }
        }
        else {
            if (element.parentElement) {
                return BeamElementHelper.getClippingElement(element.parentElement, win);
            }
        }
        return;
    }
    /**
     * Inspect the element itself and its ancestors and return the collection of elements
     * with clipping active due to the presence of `overflow`, `clip` or `clip-path` css properties
     *
     * @param element
     * @param win
     */
    static getClippingElements(element, win) {
        const clippingElement = BeamElementHelper.getClippingElement(element, win);
        if (!clippingElement) {
            return [];
        }
        if (clippingElement.parentElement && clippingElement.parentElement !== win.document.body) {
            return [
                clippingElement,
                ...BeamElementHelper.getClippingElements(clippingElement.parentElement, win)
            ];
        }
        return [clippingElement];
    }
    /**
     * Compute intersection of all the clipping areas of the given elements collection
     * the resulting area might extend infinitely in one of its dimensions
     *
     * @param elements
     * @param win
     */
    static getClippingArea(elements, win) {
        const areas = elements.map(el => {
            var _a;
            const style = (_a = win.getComputedStyle) === null || _a === void 0 ? void 0 : _a.call(win, el);
            if (style) {
                const overflowX = style.getPropertyValue("overflow-x") !== "visible";
                const overflowY = style.getPropertyValue("overflow-y") !== "visible";
                const bounds = el.getBoundingClientRect();
                if (overflowX && !overflowY) {
                    return { x: bounds.x, width: bounds.width, y: -Infinity, height: Infinity };
                }
                if (overflowY && !overflowX) {
                    return { y: bounds.y, height: bounds.height, x: -Infinity, width: Infinity };
                }
                return bounds;
            }
        });
        return areas.reduce((clippingArea, area) => (clippingArea
            ? BeamRectHelper_1.BeamRectHelper.intersection(clippingArea, area)
            : area), null);
    }
    /**
     * Returns the clipping containers which the element doesn't contain
     * @param element
     * @param win
     */
    static getClippingContainers(element, win) {
        return BeamElementHelper
            .getClippingElements(element, win)
            .filter(container => {
            const escapingElement = BeamElementHelper.getOverflowEscapingElement(element, container, win);
            return !escapingElement || escapingElement.contains(container);
        });
    }
    /**
     * Checks if target is 120% taller or 110% wider than window frame.
     *
     * @static
     * @param {DOMRect} bounds element bounds to check
     * @param {BeamWindow} win
     * @return {*}  {boolean} true if either width or height is large
     * @memberof PointAndShootHelper
     */
    static isLargerThanWindow(bounds, win) {
        const windowHeight = win.innerHeight;
        const yPercent = (100 / windowHeight) * bounds.height;
        const yIsLarge = yPercent > 110;
        // If possible return early to skip the second win.innterWidth call
        if (yIsLarge) {
            return yIsLarge;
        }
        const windowWidth = win.innerWidth;
        const xPercent = (100 / windowWidth) * bounds.width;
        const xIsLarge = xPercent > 110;
        return xIsLarge;
    }
}
exports.BeamElementHelper = BeamElementHelper;
BeamElementHelper.imageElementMatcher = (element) => ["img", "svg"].includes(element.tagName.toLowerCase());
//# sourceMappingURL=BeamElementHelper.js.map