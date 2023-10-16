export declare class BeamSize {
    width: number;
    height: number;
    constructor(width: number, height: number);
}
export declare enum MediaPlayState {
    ready = "ready",
    playing = "playing",
    paused = "paused",
    ended = "ended"
}
export interface BeamMediaState {
    playState: MediaPlayState;
    muted: boolean;
    pipSupported: boolean;
    isInPip: boolean;
}
export interface BeamRangeGroup {
    id: string;
    range: BeamRange;
    text?: string;
}
export interface BeamShootGroup {
    id: string;
    element: BeamHTMLElement;
    text?: string;
}
export interface BeamElementBounds {
    element: BeamHTMLElement | BeamElement;
    rect: BeamRect;
}
export interface BeamVisualViewport {
    /**
     * @type {number}
     */
    offsetTop: any;
    /**
     * @type {number}
     */
    pageTop: any;
    /**
     * @type {number}
     */
    offsetLeft: any;
    /**
     * @type {number}
     */
    pageLeft: any;
    /**
     * @type {number}
     */
    width: any;
    /**
     * @type {number}
     */
    height: any;
    addEventListener(name: any, cb: any): any;
}
export interface BeamResizeInfo {
    width: number;
    height: number;
}
export interface BeamEmbedContentSize {
    width: number;
    height: number;
}
export declare class BeamRect extends BeamSize {
    x: number;
    y: number;
    constructor(x: number, y: number, width: number, height: number);
}
export declare class NoteInfo {
    /**
     * @type string
     */
    id: any;
    /**
     * @type string
     */
    title: any;
}
export declare type MessagePayload = Record<string, unknown>;
export interface BeamMessageHandler {
    postMessage(message: MessagePayload, targetOrigin?: string, transfer?: Transferable[]): void;
}
export declare type MessageHandlers = {
    [name: string]: BeamMessageHandler;
};
export interface BeamWebkit<M = MessageHandlers> {
    /**
     *
     */
    messageHandlers: M;
}
export interface BeamCrypto {
    getRandomValues: any;
}
export interface BeamWindow<M = MessageHandlers> extends BeamEventTarget {
    onunload: () => void;
    matchMedia(arg0: string): any;
    crypto: BeamCrypto;
    frameElement: any;
    frames: BeamWindow[];
    /**
     * @type string
     */
    origin: any;
    /**
     * @type BeamDocument
     */
    readonly document: BeamDocument;
    /**
     * @type number
     */
    scrollY: any;
    /**
     * @type number
     */
    scrollX: any;
    /**
     * @type number
     */
    innerWidth: any;
    /**
     * @type number
     */
    innerHeight: any;
    /**
     * @type {BeamVisualViewport}
     */
    visualViewport: any;
    location: BeamLocation;
    webkit: BeamWebkit<M>;
    scroll(xCoord: number, yCoord: number): void;
    scrollTo(xCoord: number, yCoord: number): any;
    getComputedStyle(el: BeamElement, pseudo?: string): CSSStyleDeclaration;
    open(url?: string, name?: string, specs?: string, replace?: boolean): BeamWindow<M> | null;
}
export declare type BeamLocation = Location;
export declare enum BeamNodeType {
    element = 1,
    text = 3,
    processing_instruction = 7,
    comment = 8,
    document = 9,
    document_type = 10,
    document_fragment = 11
}
export interface BeamEvent {
    readonly type: string;
    readonly defaultPrevented: boolean;
}
export interface BeamEventTarget<E extends BeamEvent = BeamEvent> {
    addEventListener(type: string, callback: (e: E) => any, options?: any): any;
    removeEventListener(type: string, callback: (e: E) => any): any;
    dispatchEvent(e: E): any;
}
export declare type BeamDOMRect = DOMRect;
export declare enum BeamWebkitPresentationMode {
    inline = "inline",
    fullscreen = "fullscreen",
    pip = "picture-in-picture"
}
export interface BeamNode extends BeamEventTarget {
    isConnected?: boolean;
    offsetHeight: number;
    offsetWidth: number;
    textContent: string;
    nodeName: string;
    nodeType: BeamNodeType;
    childNodes: BeamNode[];
    parentNode?: BeamNode;
    parentElement?: BeamElement;
    muted?: boolean;
    paused?: boolean;
    webkitSetPresentationMode(BeamWebkitPresentationMode: any): any;
    /**
     * Mock-specific property
     * @deprecated Not because it will be removed, but to warn about non-standard.
     */
    bounds: BeamRect;
    /**
     * @param el {HTMLElement}
     */
    appendChild(el: BeamElement): BeamNode;
    /**
     * @param el {HTMLElement}
     */
    removeChild(el: BeamHTMLElement): any;
    contains(el: BeamNode): boolean;
}
export interface BeamParentNode extends BeamNode {
    children: BeamHTMLCollection;
}
export interface BeamCharacterData extends BeamNode {
    data: string;
}
export declare type BeamText = BeamCharacterData;
export interface BeamElement extends BeamParentNode {
    cloneNode(arg0: boolean): BeamElement;
    querySelectorAll(query: string): BeamElement[];
    removeAttribute(pointDatasetKey: any): any;
    focus(): any;
    dataset: any;
    attributes: NamedNodeMap;
    srcset?: string;
    currentSrc?: string;
    src?: string;
    id?: string;
    /**
     * @type string
     */
    innerHTML: string;
    outerHTML: string;
    classList: DOMTokenList;
    readonly offsetParent: BeamElement;
    readonly parentNode?: BeamNode;
    readonly parentElement?: BeamElement;
    /**
     * Parent padding-relative x coordinate.
     */
    offsetLeft: number;
    /**
     * Parent padding-relative y coordinate.
     */
    offsetTop: number;
    /**
     * Left border width
     */
    clientLeft: number;
    /**
     * Top border width
     */
    clientTop: number;
    height: number;
    width: number;
    scrollLeft: number;
    scrollTop: number;
    scrollHeight: number;
    scrollWidth: number;
    tagName: string;
    href: string;
    getClientRects(): DOMRectList;
    setAttribute(qualifiedName: string, value: string): void;
    getAttribute(qualifiedName: string): string | null;
    /**
     * Viewport-relative position.
     */
    getBoundingClientRect(): DOMRect;
}
export interface BeamElementCSSInlineStyle {
    style: CSSStyleDeclaration;
}
export interface BeamHTMLElement extends BeamElement, BeamElementCSSInlineStyle {
    innerText: string;
    nodeValue: any;
    dataset: Record<string, string>;
}
export interface BeamHTMLInputElement extends BeamHTMLElement {
    type: string;
    value: string;
}
export interface BeamHTMLTextAreaElement extends BeamHTMLElement {
    value: string;
}
export interface BeamHTMLIFrameElement extends BeamHTMLElement {
    src: string;
}
export interface BeamBody extends BeamHTMLElement {
    /**
     * @type String
     */
    baseURI: any;
    /**
     * @type number
     */
    scrollWidth: any;
    /**
     * @type number
     */
    offsetWidth: any;
    /**
     * @type number
     */
    clientWidth: any;
    /**
     * @type number
     */
    scrollHeight: any;
    /**
     * @type number
     */
    offsetHeight: any;
    /**
     * @type number
     */
    clientHeight: any;
}
export interface BeamRange {
    commonAncestorContainer: BeamNode;
    cloneContents(): DocumentFragment;
    cloneRange(): BeamRange;
    collapse(toStart?: boolean): void;
    compareBoundaryPoints(how: number, sourceRange: BeamRange): number;
    comparePoint(node: BeamNode, offset: number): number;
    createContextualFragment(fragment: string): DocumentFragment;
    deleteContents(): void;
    detach(): void;
    extractContents(): DocumentFragment;
    getClientRects(): DOMRectList;
    insertNode(node: BeamNode): void;
    intersectsNode(node: BeamNode): boolean;
    isPointInRange(node: BeamNode, offset: number): boolean;
    selectNodeContents(node: BeamNode): void;
    setEnd(node: BeamNode, offset: number): void;
    setEndAfter(node: BeamNode): void;
    setEndBefore(node: BeamNode): void;
    setStart(node: BeamNode, offset: number): void;
    setStartAfter(node: BeamNode): void;
    setStartBefore(node: BeamNode): void;
    surroundContents(newParent: BeamNode): void;
    toString(): string;
    END_TO_END: number;
    END_TO_START: number;
    START_TO_END: number;
    START_TO_START: number;
    collapsed: boolean;
    endContainer: BeamNode;
    endOffset: number;
    startContainer: BeamNode;
    startOffset: number;
    selectNode(node: BeamNode): void;
    getBoundingClientRect(): DOMRect;
}
export declare const BeamRange: {
    prototype: BeamRange;
    new (): BeamRange;
    readonly END_TO_END: number;
    readonly END_TO_START: number;
    readonly START_TO_END: number;
    readonly START_TO_START: number;
    toString(): string;
};
export interface BeamDocument extends BeamNode {
    createDocumentFragment(): any;
    elementFromPoint(x: any, y: any): any;
    createTreeWalker(root: BeamNode, whatToShow?: number, filter?: NodeFilter | null, expandEntityReferences?: boolean): TreeWalker;
    createTextNode(data: string): Text;
    /**
     * @type {HTMLHtmlElement}
     */
    documentElement: any;
    activeElement: BeamHTMLElement;
    /**
     * @type BeamBody
     */
    body: BeamBody;
    /**
     * @param tag {string}
     */
    createElement(tag: any): any;
    /**
     * @return {BeamSelection}
     */
    getSelection(): any;
    /**
     * @param selector {string}
     * @return {HTMLElement[]}
     */
    querySelectorAll(selector: string): BeamNode[];
    /**
     * @param selector {string}
     * @return {HTMLElement}
     */
    querySelector(selector: string): BeamNode;
    createRange(): BeamRange;
}
/**
 * {x, y} of mouse location
 *
 * @export
 * @interface BeamMouseLocation
 */
export interface BeamMouseLocation {
    x: number;
    y: number;
}
export interface BeamSelection {
    anchorNode: BeamNode;
    anchorOffset: number;
    focusNode: BeamNode;
    focusOffset: number;
    isCollapsed: boolean;
    rangeCount: number;
    type: string;
    addRange(range: BeamRange): void;
    collapse(node: BeamNode, offset?: number): void;
    collapseToEnd(): void;
    collapseToStart(): void;
    containsNode(node: BeamNode, allowPartialContainment?: boolean): boolean;
    deleteFromDocument(): void;
    empty(): void;
    extend(node: BeamNode, offset?: number): void;
    getRangeAt(index: number): BeamRange;
    removeAllRanges(): void;
    removeRange(range: BeamRange): void;
    selectAllChildren(node: BeamNode): void;
    setBaseAndExtent(anchorNode: BeamNode, anchorOffset: number, focusNode: BeamNode, focusOffset: number): void;
    setPosition(node: BeamNode, offset?: number): void;
    toString(): string;
}
export interface BeamMutationRecord {
    addedNodes: BeamNode[];
    attributeName: string;
    attributeNamespace: string;
    nextSibling: BeamNode;
    oldValue: string;
    previousSibling: BeamNode;
    removedNodes: BeamNode[];
    target: BeamNode;
    type: MutationRecordType;
}
export declare class BeamMutationObserver {
    fn: any;
    constructor(fn: any);
    disconnect(): void;
    observe(_target: BeamNode, _options?: MutationObserverInit): void;
    takeRecords(): BeamMutationRecord[];
}
export declare class BeamResizeObserver implements ResizeObserver {
    constructor();
    disconnect(): void;
    observe(target: Element, options?: ResizeObserverOptions): void;
    unobserve(target: Element): void;
}
export interface BeamCoordinates {
    x: number;
    y: number;
}
export declare class FrameInfo {
    /**
     */
    href: string;
    /**
     */
    bounds: BeamRect;
    scrollSize?: BeamFrameScrollSizing;
}
export interface BeamFrameScrollSizing {
    width: number;
    height: number;
}
export declare enum BeamLogLevel {
    log = "log",
    warning = "warning",
    error = "error",
    debug = "debug"
}
export declare enum BeamLogCategory {
    general = "general",
    pointAndShoot = "pointAndShoot",
    embedNode = "embedNode",
    webpositions = "webpositions",
    navigation = "navigation",
    native = "native",
    passwordManager = "passwordManager",
    webAutofillInternal = "webAutofillInternal"
}
export declare class BeamHTMLCollection<E extends BeamElement = BeamElement> {
    private values;
    constructor(values: E[]);
    [index: number]: E;
    get length(): number;
    [Symbol.iterator](): IterableIterator<E>;
    item(index: number): E | null;
    namedItem(name: string): E | null;
}
