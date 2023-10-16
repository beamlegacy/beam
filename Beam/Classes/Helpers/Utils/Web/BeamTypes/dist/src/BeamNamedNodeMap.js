"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BeamNamedNodeMap = void 0;
class BeamNamedNodeMap extends Object {
    constructor(props = {}) {
        super();
        this.attrs = [];
        for (const p in props) {
            if (Object.prototype.hasOwnProperty.call(props, p)) {
                const attr = {
                    ATTRIBUTE_NODE: 0,
                    CDATA_SECTION_NODE: 0,
                    COMMENT_NODE: 0,
                    DOCUMENT_FRAGMENT_NODE: 0,
                    DOCUMENT_NODE: 0,
                    DOCUMENT_POSITION_CONTAINED_BY: 0,
                    DOCUMENT_POSITION_CONTAINS: 0,
                    DOCUMENT_POSITION_DISCONNECTED: 0,
                    DOCUMENT_POSITION_FOLLOWING: 0,
                    DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC: 0,
                    DOCUMENT_POSITION_PRECEDING: 0,
                    DOCUMENT_TYPE_NODE: 0,
                    ELEMENT_NODE: 0,
                    ENTITY_NODE: 0,
                    ENTITY_REFERENCE_NODE: 0,
                    NOTATION_NODE: 0,
                    PROCESSING_INSTRUCTION_NODE: 0,
                    TEXT_NODE: 0,
                    addEventListener(type, listener, options) {
                        // TODO: Shouldn't we implement it?
                    },
                    appendChild(newChild) {
                        // TODO: Shouldn't we implement it?
                        return undefined;
                    },
                    baseURI: "",
                    childNodes: undefined,
                    cloneNode(deep) {
                        // TODO: Shouldn't we implement it?
                        return undefined;
                    },
                    compareDocumentPosition(other) {
                        return 0;
                    },
                    contains(other) {
                        return false;
                    },
                    dispatchEvent(event) {
                        return false;
                    },
                    firstChild: undefined,
                    getRootNode(options) {
                        return undefined;
                    },
                    hasChildNodes() {
                        return false;
                    },
                    insertBefore(newChild, refChild) {
                        return undefined;
                    },
                    isConnected: false,
                    isDefaultNamespace(namespace) {
                        return false;
                    },
                    isEqualNode(otherNode) {
                        return false;
                    },
                    isSameNode(otherNode) {
                        return false;
                    },
                    lastChild: undefined,
                    lookupNamespaceURI(prefix) {
                        return undefined;
                    },
                    lookupPrefix(namespace) {
                        return undefined;
                    },
                    namespaceURI: undefined,
                    nextSibling: undefined,
                    nodeName: "",
                    nodeType: 0,
                    nodeValue: undefined,
                    ownerDocument: undefined,
                    ownerElement: undefined,
                    parentElement: undefined,
                    parentNode: undefined,
                    prefix: undefined,
                    previousSibling: undefined,
                    removeChild(oldChild) {
                        return undefined;
                    },
                    removeEventListener(type, callback, options) {
                        // TODO: Shouldn't we implement it?
                    },
                    replaceChild(newChild, oldChild) {
                        return undefined;
                    },
                    specified: false,
                    textContent: undefined,
                    normalize() {
                        // TODO: Shouldn't we implement it?
                    },
                    name: p,
                    localName: p,
                    value: props[p]
                };
                this.setNamedItem(attr);
            }
        }
    }
    get length() {
        return this.attrs.length;
    }
    getNamedItem(qualifiedName) {
        return this.attrs.find((a) => a.localName === qualifiedName);
    }
    getNamedItemNS(namespace, localName) {
        return this.getNamedItem(`${namespace}.${localName}`);
    }
    item(index) {
        return this.attrs[index];
    }
    removeNamedItem(qualifiedName) {
        const old = this.getNamedItem(qualifiedName);
        const index = this.attrs.indexOf(old);
        this.attrs.splice(index, 1);
        return old;
    }
    removeNamedItemNS(namespace, localName) {
        return this.removeNamedItem(namespace + "." + localName);
    }
    setNamedItem(attr) {
        const old = this.getNamedItem(attr.localName);
        if (old) {
            this.removeNamedItem(attr.localName);
        }
        this.attrs.push(attr);
        return old;
    }
    setNamedItemNS(attr) {
        return undefined;
    }
    [Symbol.iterator]() {
        return this.attrs.values();
    }
    toString() {
        return this.attrs.map((a) => `${a.name}="${a.value}"`).join(" ");
    }
}
exports.BeamNamedNodeMap = BeamNamedNodeMap;
//# sourceMappingURL=BeamNamedNodeMap.js.map