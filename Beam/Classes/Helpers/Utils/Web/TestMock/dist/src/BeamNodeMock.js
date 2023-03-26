"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BeamNodeMock = void 0;
const BeamEventTargetMock_1 = require("./BeamEventTargetMock");
const native_beamtypes_1 = require("@beam/native-beamtypes");
class BeamNodeMock extends BeamEventTargetMock_1.BeamEventTargetMock {
    constructor(nodeName, nodeType, props = {}) {
        super();
        this.nodeName = nodeName;
        this.nodeType = nodeType;
        this.childNodes = [];
        this.isConnected = true;
        /**
         * @deprecated Not standard, for test purpose
         * Relative bounds
         */
        this.bounds = new native_beamtypes_1.BeamRect(0, 0, 0, 0);
        Object.assign(this, props);
        this.nodeName = nodeName;
        this.nodeType = nodeType;
    }
    webkitSetPresentationMode(BeamWebkitPresentationMode) {
        throw new Error("Method not implemented.");
    }
    appendChild(node) {
        this.childNodes.push(node);
        node.parentNode = this;
        node.parentElement = this;
        return node;
    }
    removeChild(el) {
        this.childNodes = this.childNodes.splice(this.childNodes.indexOf(el), 1);
        el.parentNode = null;
        el.parentElement = null;
    }
    contains(el) {
        return this === el || this.childNodes.some((childNode) => childNode === el || childNode.contains(el));
    }
    get textContent() {
        const collectTextNodes = (node) => {
            const text = node.childNodes.reduce((acc, node) => {
                if (node.nodeType === native_beamtypes_1.BeamNodeType.text) {
                    acc.push(`${node}`);
                }
                else if (node.nodeType === native_beamtypes_1.BeamNodeType.element) {
                    acc.push(...collectTextNodes(node));
                }
                return acc;
            }, []);
            return text.join("");
        };
        return collectTextNodes(this);
    }
}
exports.BeamNodeMock = BeamNodeMock;
BeamNodeMock.ELEMENT_NODE = native_beamtypes_1.BeamNodeType.element;
BeamNodeMock.TEXT_NODE = native_beamtypes_1.BeamNodeType.text;
BeamNodeMock.PROCESSING_INSTRUCTION_NODE = native_beamtypes_1.BeamNodeType.processing_instruction;
BeamNodeMock.COMMENT_NODE = native_beamtypes_1.BeamNodeType.comment;
BeamNodeMock.DOCUMENT_NODE = native_beamtypes_1.BeamNodeType.document;
BeamNodeMock.DOCUMENT_TYPE_NODE = native_beamtypes_1.BeamNodeType.document_type;
BeamNodeMock.DOCUMENT_FRAGMENT_NODE = native_beamtypes_1.BeamNodeType.document_fragment;
//# sourceMappingURL=BeamNodeMock.js.map