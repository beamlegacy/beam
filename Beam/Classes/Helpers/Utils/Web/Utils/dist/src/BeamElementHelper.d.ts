import { BeamElement, BeamHTMLElement, BeamRect, BeamWindow } from "@beam/native-beamtypes";
/**
 * Useful methods for HTML Elements
 */
export declare class BeamElementHelper {
    static getAttribute(attr: string, element: BeamElement): string;
    static getType(element: BeamElement): string;
    static getContentEditable(element: BeamElement): string;
    /**
     * Returns if an element is a textarea or an input elements with a text
     * based input type (text, email, date, number...)
     *
     * @param element {BeamHTMLElement} The DOM Element to check.
     * @return If the element is some kind of text input.
     */
    static isTextualInputType(element: BeamHTMLElement): boolean;
    /**
     * Returns the text value for a given element, text value meaning either
     * the element's innerText or the input value
     *
     * @param el
     */
    static getTextValue(el: BeamElement): string;
    static getBackgroundImageURL(element: BeamElement, win: BeamWindow): string | null;
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
    static hasParentOfType(element: BeamElement, type: string, count?: number): BeamElement | undefined;
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
    static parseElementBasedOnStyles(element: BeamElement, win: BeamWindow<any>): BeamHTMLElement;
    /**
     * Determine whether or not an element is visible based on it's style
     * and bounding box if necessary
     *
     * @param element: {BeamElement}
     * @param win: {BeamWindow}
     * @return If the element is considered visible
     */
    static isVisible(element: BeamElement, win: BeamWindow<any>): boolean;
    /**
     * Returns whether an element is either a video or an audio element
     *
     * @param element
     */
    static isMedia(element: BeamElement): boolean;
    /**
     * Check whether an element is an image, or has a background-image url
     * the background image can be a data:uri. Or has any child that is a img or svg.
     *
     * @param element
     * @param win
     * @return If the element is considered visible
     */
    static isImageOrContainsImageChild(element: BeamElement, win: BeamWindow): boolean;
    static imageElementMatcher: (element: BeamElement) => boolean;
    /**
     * Check whether an element is an image, or has a background-image url
     * the background image can be a data:uri
     *
     * @param element
     * @param win
     * @return If the element is considered visible
     */
    static isImage(element: BeamElement, win: BeamWindow, matcher?: (element: BeamElement) => boolean): boolean;
    /**
     * Returns whether an element is an image container, which means it can be an image
     * itself or recursively contain only image containers
     *
     * @param element
     * @param win
     */
    static isImageContainer(element: BeamElement, win: BeamWindow): boolean;
    /**
     * Returns the root svg element for the given element if any
     * @param element
     */
    static getSvgRoot(element: BeamElement): BeamElement;
    /**
     * Returns the first positioned element out of the element itself and its ancestors
     *
     * @param element
     * @param win
     */
    static getPositionedElement(element: BeamElement, win: BeamWindow): BeamElement;
    /**
     * Return the first overflow escaping element. Since css overflow can be escaped by positioning
     * an element relative to the viewport, either by using `fixed`, or `absolute` in the case
     * there's no other positioning context
     *
     * @param element
     * @param clippingContainer
     * @param win
     */
    static getOverflowEscapingElement(element: BeamElement, clippingContainer: BeamElement, win: BeamWindow): BeamElement;
    /**
     * Recursively look for the first ancestor element with an `overflow`, `clip`, or `clip-path
     * css property triggering clipping on the element
     *
     * @param element
     * @param win
     */
    static getClippingElement(element: BeamElement, win: BeamWindow): BeamElement;
    /**
     * Inspect the element itself and its ancestors and return the collection of elements
     * with clipping active due to the presence of `overflow`, `clip` or `clip-path` css properties
     *
     * @param element
     * @param win
     */
    static getClippingElements(element: BeamElement, win: BeamWindow<any>): BeamElement[];
    /**
     * Compute intersection of all the clipping areas of the given elements collection
     * the resulting area might extend infinitely in one of its dimensions
     *
     * @param elements
     * @param win
     */
    static getClippingArea(elements: BeamElement[], win: BeamWindow<any>): BeamRect;
    /**
     * Returns the clipping containers which the element doesn't contain
     * @param element
     * @param win
     */
    static getClippingContainers(element: BeamElement, win: BeamWindow): BeamElement[];
    /**
     * Checks if target is 120% taller or 110% wider than window frame.
     *
     * @static
     * @param {DOMRect} bounds element bounds to check
     * @param {BeamWindow} win
     * @return {*}  {boolean} true if either width or height is large
     * @memberof PointAndShootHelper
     */
    static isLargerThanWindow(bounds: DOMRect, win: BeamWindow): boolean;
}
