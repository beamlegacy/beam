"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BeamElementMock = void 0;
const BeamNodeMock_1 = require("./BeamNodeMock");
const native_beamtypes_1 = require("@beam/native-beamtypes");
const native_utils_1 = require("@beam/native-utils");
const BeamDOMRectMock_1 = require("./BeamDOMRectMock");
class BeamElementMock extends BeamNodeMock_1.BeamNodeMock {
    constructor(tagName, attributes = new native_beamtypes_1.BeamNamedNodeMap(), props = {}) {
        super(tagName, native_beamtypes_1.BeamNodeType.element);
        this.tagName = tagName;
        this.clientLeft = 0;
        this.clientTop = 0;
        this.offsetLeft = 0;
        this.offsetTop = 0;
        this.scrollLeft = 0;
        this.scrollTop = 0;
        this._height = 0;
        this._width = 0;
        this.querySelectorResult = {};
        this.attributes = attributes;
    }
    focus() {
        // todo
    }
    setQuerySelectorResult(query, element) {
        // if no array exists yet, create one
        if (!this.querySelectorResult[query]) {
            this.querySelectorResult[query] = [];
        }
        this.querySelectorResult[query].push(element);
    }
    cloneNode() {
        return Object.assign({}, this);
    }
    querySelectorAll(query) {
        if (query == "*") {
            const arrays = Object.values(this.querySelectorResult) || [];
            return [].concat(...arrays);
        }
        return this.querySelectorResult[query] || [];
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
    set width(value) {
        this._width = value;
        this.scrollWidth = value;
    }
    get width() {
        return this._width;
    }
    get height() {
        return this._height;
    }
    set height(value) {
        this._height = value;
        this.scrollHeight = value;
    }
    appendChild(node) {
        const added = super.appendChild(node);
        if (node instanceof BeamElementMock) {
            node.offsetParent = this;
        }
        return added;
    }
    get _children() {
        return this.childNodes.filter((e) => e.nodeType === BeamNodeMock_1.BeamNodeMock.ELEMENT_NODE);
    }
    get children() {
        const beamNodes = this._children;
        return new native_beamtypes_1.BeamHTMLCollection(beamNodes);
    }
    get innerHTML() {
        return this.childNodes.map((c) => c.toString()).join("");
    }
    get outerHTML() {
        const tag = this.nodeName;
        let attributes = "";
        for (const a of Array.from(this.attributes)) {
            attributes += ` ${a.name}="${a.value}"`;
        }
        return `<${tag}${attributes}>${this.innerHTML}</${tag}>`;
    }
    toString() {
        return this.outerHTML;
    }
    getBoundingClientRect() {
        const xy = native_utils_1.PointAndShootHelper.getTopLeft(this);
        return new BeamDOMRectMock_1.BeamDOMRectMock(xy.x, xy.y, this.width, this.height);
    }
    getClientRects() {
        const list = this._children.map((c) => c.getBoundingClientRect());
        return new native_beamtypes_1.BeamDOMRectList(list);
    }
}
exports.BeamElementMock = BeamElementMock;
//# sourceMappingURL=BeamElementMock.js.map