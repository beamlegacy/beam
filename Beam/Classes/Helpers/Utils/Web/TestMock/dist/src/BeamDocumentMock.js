"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BeamDocumentMock = exports.BeamTreeWalker = exports.BeamDocumentMockDefaults = void 0;
const native_beamtypes_1 = require("@beam/native-beamtypes");
const BeamSelectionMock_1 = require("./BeamSelectionMock");
const BeamNodeMock_1 = require("./BeamNodeMock");
const BeamElementMock_1 = require("./BeamElementMock");
const BeamRangeMock_1 = require("./BeamRangeMock");
const BeamHTMLElementMock_1 = require("./BeamHTMLElementMock");
exports.BeamDocumentMockDefaults = {
    body: {
        styleData: {
            style: {
                zoom: "1"
            }
        },
        scrollData: {
            scrollWidth: 800,
            scrollHeight: 0,
            offsetWidth: 800,
            offsetHeight: 0,
            clientWidth: 800,
            clientHeight: 0
        }
    },
    documentElement: {
        scrollWidth: 800,
        scrollHeight: 0,
        offsetWidth: 800,
        offsetHeight: 0,
        clientWidth: 800,
        clientHeight: 0
    }
};
class BeamTreeWalker {
    constructor(root, whatToShow, filter) {
        this.root = root;
        this.currentNode = root;
        this.whatToShow = whatToShow;
        this.filter = filter;
    }
    firstChild() {
        return this.currentNode.firstChild;
    }
    lastChild() {
        return this.currentNode.lastChild;
    }
    nextNode() {
        return this.currentNode.nextSibling;
    }
    nextSibling() {
        return this.currentNode.nextSibling;
    }
    parentNode() {
        return this.currentNode.parentNode;
    }
    previousNode() {
        return this.currentNode.previousSibling;
    }
    previousSibling() {
        return this.currentNode.previousSibling;
    }
}
exports.BeamTreeWalker = BeamTreeWalker;
class BeamDocumentMock extends BeamNodeMock_1.BeamNodeMock {
    constructor(attributes = {}) {
        super("#document", native_beamtypes_1.BeamNodeType.document);
        /**
         * @type {HTMLHtmlElement}
         */
        this.documentElement = new BeamHTMLElementMock_1.BeamHTMLElementMock("div", {});
        this.body = {};
        this.selection = new BeamSelectionMock_1.BeamSelectionMock("div");
        this.childNodes = [new BeamNodeMock_1.BeamNodeMock("#text", 3)];
        Object.assign(this, attributes);
    }
    createTreeWalker(root, whatToShow, filter, _expandEntityReferences) {
        return new BeamTreeWalker(root, whatToShow, filter);
    }
    createTextNode(data) {
        throw new Error("Method not implemented.");
    }
    webkitSetPresentationMode(BeamWebkitPresentationMode) {
        throw new Error("Method not implemented.");
    }
    createDocumentFragment() {
        throw new Error("Method not implemented.");
    }
    elementFromPoint(x, y) {
        return this.documentElement;
    }
    /**
     * @param tag {string}
     */
    createElement(tag) {
        return new BeamElementMock_1.BeamElementMock(tag);
    }
    /**
     *
     * @param eventName {String}
     * @param cb {Function}
     */
    addEventListener(eventName, cb) {
        // TODO: Shouldn't we implement it?
    }
    /**
     * @return {BeamSelection}
     */
    getSelection() {
        return this.selection;
    }
    /**
     * @param selector {string}
     * @return {HTMLElement[]}
     */
    querySelectorAll(selector) {
        return []; // Override it in your custom mock
    }
    createRange() {
        return new BeamRangeMock_1.BeamRangeMock();
    }
    /**
     * @param selector {string}
     * @return {HTMLElement[]}
     */
    querySelector(selector) {
        return;
    }
}
exports.BeamDocumentMock = BeamDocumentMock;
//# sourceMappingURL=BeamDocumentMock.js.map