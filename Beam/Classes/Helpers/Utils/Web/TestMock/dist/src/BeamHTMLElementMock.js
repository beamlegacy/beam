"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BeamHTMLElementMock = void 0;
const native_beamtypes_1 = require("@beam/native-beamtypes");
const BeamElementMock_1 = require("./BeamElementMock");
const BeamTextMock_1 = require("./BeamTextMock");
class BeamHTMLElementMock extends BeamElementMock_1.BeamElementMock {
    constructor(nodeName, attributes = {}) {
        super(nodeName, new native_beamtypes_1.BeamNamedNodeMap(attributes));
        this.querySelectorResult = {};
        this.dataset = {
            "beam-mock": "uuid-uuid-uuid-uuid"
        };
    }
    setQuerySelectorResult(query, element) {
        // if no array exists yet, create one
        if (!this.querySelectorResult[query]) {
            this.querySelectorResult[query] = [];
        }
        this.querySelectorResult[query].push(element);
    }
    querySelectorAll(query) {
        if (query == "*") {
            const arrays = Object.values(this.querySelectorResult) || [];
            return [].concat(...arrays);
        }
        return this.querySelectorResult[query] || [];
    }
    querySelector(query) {
        if (query == "*") {
            const arrays = Object.values(this.querySelectorResult) || [];
            return [].concat(...arrays).pop();
        }
        return this.querySelectorResult[query].pop();
    }
    removeAttribute(pointDatasetKey) {
        delete this.attributes[pointDatasetKey];
    }
    setAttribute(qualifiedName, value) {
        const attr = document.createAttribute(qualifiedName);
        attr.value = value;
        this.attributes.setNamedItem(attr);
    }
    getAttribute(qualifiedName) {
        const item = this.attributes.getNamedItem(qualifiedName);
        return item === null || item === void 0 ? void 0 : item.value;
    }
    get innerText() {
        return this.textContent;
    }
    set innerText(text) {
        const textNodes = this.childNodes.filter((node) => node.nodeType === native_beamtypes_1.BeamNodeType.text);
        for (const textNode of textNodes) {
            this.removeChild(textNode);
        }
        this.appendChild(new BeamTextMock_1.BeamTextMock(text));
    }
}
exports.BeamHTMLElementMock = BeamHTMLElementMock;
//# sourceMappingURL=BeamHTMLElementMock.js.map