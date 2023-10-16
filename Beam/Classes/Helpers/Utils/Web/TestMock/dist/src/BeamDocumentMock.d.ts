import { BeamDocument, BeamHTMLElement, BeamNode, BeamRange, BeamSelection } from "@beam/native-beamtypes";
import { BeamNodeMock } from "./BeamNodeMock";
import { BeamElementMock } from "./BeamElementMock";
export declare const BeamDocumentMockDefaults: {
    body: {
        styleData: {
            style: {
                zoom: string;
            };
        };
        scrollData: {
            scrollWidth: number;
            scrollHeight: number;
            offsetWidth: number;
            offsetHeight: number;
            clientWidth: number;
            clientHeight: number;
        };
    };
    documentElement: {
        scrollWidth: number;
        scrollHeight: number;
        offsetWidth: number;
        offsetHeight: number;
        clientWidth: number;
        clientHeight: number;
    };
};
export declare class BeamTreeWalker implements TreeWalker {
    currentNode: Node;
    filter: NodeFilter;
    root: Node;
    whatToShow: number;
    constructor(root: any, whatToShow: any, filter: any);
    firstChild(): Node;
    lastChild(): Node;
    nextNode(): Node;
    nextSibling(): Node;
    parentNode(): Node;
    previousNode(): Node;
    previousSibling(): Node;
}
export declare class BeamDocumentMock extends BeamNodeMock implements BeamDocument {
    /**
     * @type {HTMLHtmlElement}
     */
    documentElement: BeamHTMLElement;
    activeElement: BeamHTMLElement;
    /**
     * @type BeamBody
     */
    body: any;
    private selection;
    constructor(attributes?: {});
    createTreeWalker(root: BeamNode, whatToShow?: number, filter?: NodeFilter, _expandEntityReferences?: boolean): TreeWalker;
    createTextNode(data: string): Text;
    muted?: boolean;
    paused?: boolean;
    webkitSetPresentationMode(BeamWebkitPresentationMode: any): void;
    createDocumentFragment(): void;
    elementFromPoint(x: any, y: any): BeamHTMLElement;
    /**
     * @param tag {string}
     */
    createElement(tag: any): BeamElementMock;
    /**
     *
     * @param eventName {String}
     * @param cb {Function}
     */
    addEventListener(eventName: any, cb: any): void;
    /**
     * @return {BeamSelection}
     */
    getSelection(): BeamSelection;
    /**
     * @param selector {string}
     * @return {HTMLElement[]}
     */
    querySelectorAll(selector: any): BeamNode[];
    createRange(): BeamRange;
    /**
     * @param selector {string}
     * @return {HTMLElement[]}
     */
    querySelector(selector: any): BeamNode;
}
