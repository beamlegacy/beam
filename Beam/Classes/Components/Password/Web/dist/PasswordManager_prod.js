/******/ (() => { // webpackBootstrap
/******/ 	var __webpack_modules__ = ({

/***/ "../../../../../.yarn/cache/dequal-npm-2.0.2-370927eb6c-86c7a2c59f.zip/node_modules/dequal/dist/index.js":
/*!***************************************************************************************************************!*\
  !*** ../../../../../.yarn/cache/dequal-npm-2.0.2-370927eb6c-86c7a2c59f.zip/node_modules/dequal/dist/index.js ***!
  \***************************************************************************************************************/
/***/ ((__unused_webpack_module, exports) => {

var has = Object.prototype.hasOwnProperty;

function find(iter, tar, key) {
	for (key of iter.keys()) {
		if (dequal(key, tar)) return key;
	}
}

function dequal(foo, bar) {
	var ctor, len, tmp;
	if (foo === bar) return true;

	if (foo && bar && (ctor=foo.constructor) === bar.constructor) {
		if (ctor === Date) return foo.getTime() === bar.getTime();
		if (ctor === RegExp) return foo.toString() === bar.toString();

		if (ctor === Array) {
			if ((len=foo.length) === bar.length) {
				while (len-- && dequal(foo[len], bar[len]));
			}
			return len === -1;
		}

		if (ctor === Set) {
			if (foo.size !== bar.size) {
				return false;
			}
			for (len of foo) {
				tmp = len;
				if (tmp && typeof tmp === 'object') {
					tmp = find(bar, tmp);
					if (!tmp) return false;
				}
				if (!bar.has(tmp)) return false;
			}
			return true;
		}

		if (ctor === Map) {
			if (foo.size !== bar.size) {
				return false;
			}
			for (len of foo) {
				tmp = len[0];
				if (tmp && typeof tmp === 'object') {
					tmp = find(bar, tmp);
					if (!tmp) return false;
				}
				if (!dequal(len[1], bar.get(tmp))) {
					return false;
				}
			}
			return true;
		}

		if (ctor === ArrayBuffer) {
			foo = new Uint8Array(foo);
			bar = new Uint8Array(bar);
		} else if (ctor === DataView) {
			if ((len=foo.byteLength) === bar.byteLength) {
				while (len-- && foo.getInt8(len) === bar.getInt8(len));
			}
			return len === -1;
		}

		if (ArrayBuffer.isView(foo)) {
			if ((len=foo.byteLength) === bar.byteLength) {
				while (len-- && foo[len] === bar[len]);
			}
			return len === -1;
		}

		if (!ctor || typeof foo === 'object') {
			len = 0;
			for (ctor in foo) {
				if (has.call(foo, ctor) && ++len && !has.call(bar, ctor)) return false;
				if (!(ctor in bar) || !dequal(foo[ctor], bar[ctor])) return false;
			}
			return Object.keys(bar).length === len;
		}
	}

	return foo !== foo && bar !== bar;
}

exports.dequal = dequal;

/***/ }),

/***/ "../../../Helpers/Utils/Web/BeamTypes/dist/src/BeamDOMRectList.js":
/*!************************************************************************!*\
  !*** ../../../Helpers/Utils/Web/BeamTypes/dist/src/BeamDOMRectList.js ***!
  \************************************************************************/
/***/ ((__unused_webpack_module, exports) => {

"use strict";

Object.defineProperty(exports, "__esModule", ({ value: true }));
exports.BeamDOMRectList = void 0;
class BeamDOMRectList {
    constructor(list) {
        this.list = list;
    }
    get length() {
        return this.list.length;
    }
    [Symbol.iterator]() {
        return this.list.values();
    }
    item(index) {
        return this.list[index];
    }
}
exports.BeamDOMRectList = BeamDOMRectList;


/***/ }),

/***/ "../../../Helpers/Utils/Web/BeamTypes/dist/src/BeamKeyEvent.js":
/*!*********************************************************************!*\
  !*** ../../../Helpers/Utils/Web/BeamTypes/dist/src/BeamKeyEvent.js ***!
  \*********************************************************************/
/***/ ((__unused_webpack_module, exports, __webpack_require__) => {

"use strict";

Object.defineProperty(exports, "__esModule", ({ value: true }));
exports.BeamKeyEvent = void 0;
const BeamMouseEvent_1 = __webpack_require__(/*! ./BeamMouseEvent */ "../../../Helpers/Utils/Web/BeamTypes/dist/src/BeamMouseEvent.js");
class BeamKeyEvent extends BeamMouseEvent_1.BeamMouseEvent {
    constructor(attributes = {}) {
        super();
        Object.assign(this, attributes);
    }
}
exports.BeamKeyEvent = BeamKeyEvent;


/***/ }),

/***/ "../../../Helpers/Utils/Web/BeamTypes/dist/src/BeamMouseEvent.js":
/*!***********************************************************************!*\
  !*** ../../../Helpers/Utils/Web/BeamTypes/dist/src/BeamMouseEvent.js ***!
  \***********************************************************************/
/***/ ((__unused_webpack_module, exports, __webpack_require__) => {

"use strict";

Object.defineProperty(exports, "__esModule", ({ value: true }));
exports.BeamMouseEvent = void 0;
const BeamUIEvent_1 = __webpack_require__(/*! ./BeamUIEvent */ "../../../Helpers/Utils/Web/BeamTypes/dist/src/BeamUIEvent.js");
class BeamMouseEvent extends BeamUIEvent_1.BeamUIEvent {
    constructor(attributes = {}) {
        super();
        Object.assign(this, attributes);
    }
}
exports.BeamMouseEvent = BeamMouseEvent;


/***/ }),

/***/ "../../../Helpers/Utils/Web/BeamTypes/dist/src/BeamNamedNodeMap.js":
/*!*************************************************************************!*\
  !*** ../../../Helpers/Utils/Web/BeamTypes/dist/src/BeamNamedNodeMap.js ***!
  \*************************************************************************/
/***/ ((__unused_webpack_module, exports) => {

"use strict";

Object.defineProperty(exports, "__esModule", ({ value: true }));
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


/***/ }),

/***/ "../../../Helpers/Utils/Web/BeamTypes/dist/src/BeamTypes.js":
/*!******************************************************************!*\
  !*** ../../../Helpers/Utils/Web/BeamTypes/dist/src/BeamTypes.js ***!
  \******************************************************************/
/***/ ((__unused_webpack_module, exports) => {

"use strict";

/*
 * Types used by Beam API (to exchange messages, typically).
 */
Object.defineProperty(exports, "__esModule", ({ value: true }));
exports.BeamHTMLCollection = exports.BeamLogCategory = exports.BeamLogLevel = exports.FrameInfo = exports.BeamResizeObserver = exports.BeamMutationObserver = exports.BeamWebkitPresentationMode = exports.BeamNodeType = exports.NoteInfo = exports.BeamRect = exports.MediaPlayState = exports.BeamSize = void 0;
class BeamSize {
    constructor(width, height) {
        this.width = width;
        this.height = height;
    }
}
exports.BeamSize = BeamSize;
var MediaPlayState;
(function (MediaPlayState) {
    MediaPlayState["ready"] = "ready";
    MediaPlayState["playing"] = "playing";
    MediaPlayState["paused"] = "paused";
    MediaPlayState["ended"] = "ended";
})(MediaPlayState = exports.MediaPlayState || (exports.MediaPlayState = {}));
class BeamRect extends BeamSize {
    constructor(x, y, width, height) {
        super(width, height);
        this.x = x;
        this.y = y;
    }
}
exports.BeamRect = BeamRect;
class NoteInfo {
}
exports.NoteInfo = NoteInfo;
var BeamNodeType;
(function (BeamNodeType) {
    BeamNodeType[BeamNodeType["element"] = 1] = "element";
    BeamNodeType[BeamNodeType["text"] = 3] = "text";
    BeamNodeType[BeamNodeType["processing_instruction"] = 7] = "processing_instruction";
    BeamNodeType[BeamNodeType["comment"] = 8] = "comment";
    BeamNodeType[BeamNodeType["document"] = 9] = "document";
    BeamNodeType[BeamNodeType["document_type"] = 10] = "document_type";
    BeamNodeType[BeamNodeType["document_fragment"] = 11] = "document_fragment";
})(BeamNodeType = exports.BeamNodeType || (exports.BeamNodeType = {}));
var BeamWebkitPresentationMode;
(function (BeamWebkitPresentationMode) {
    BeamWebkitPresentationMode["inline"] = "inline";
    BeamWebkitPresentationMode["fullscreen"] = "fullscreen";
    BeamWebkitPresentationMode["pip"] = "picture-in-picture";
})(BeamWebkitPresentationMode = exports.BeamWebkitPresentationMode || (exports.BeamWebkitPresentationMode = {}));
class BeamMutationObserver {
    constructor(fn) {
        this.fn = fn;
        new fn();
    }
    disconnect() {
        throw new Error("Method not implemented.");
    }
    observe(_target, _options) {
        throw new Error("Method not implemented.");
    }
    takeRecords() {
        throw new Error("Method not implemented.");
    }
}
exports.BeamMutationObserver = BeamMutationObserver;
class BeamResizeObserver {
    constructor() { }
    disconnect() {
        throw new Error("Method not implemented.");
    }
    observe(target, options) {
        throw new Error("Method not implemented.");
    }
    unobserve(target) {
        throw new Error("Method not implemented.");
    }
}
exports.BeamResizeObserver = BeamResizeObserver;
class FrameInfo {
}
exports.FrameInfo = FrameInfo;
var BeamLogLevel;
(function (BeamLogLevel) {
    BeamLogLevel["log"] = "log";
    BeamLogLevel["warning"] = "warning";
    BeamLogLevel["error"] = "error";
    BeamLogLevel["debug"] = "debug";
})(BeamLogLevel = exports.BeamLogLevel || (exports.BeamLogLevel = {}));
var BeamLogCategory;
(function (BeamLogCategory) {
    BeamLogCategory["general"] = "general";
    BeamLogCategory["pointAndShoot"] = "pointAndShoot";
    BeamLogCategory["embedNode"] = "embedNode";
    BeamLogCategory["webpositions"] = "webpositions";
    BeamLogCategory["navigation"] = "navigation";
    BeamLogCategory["native"] = "native";
    BeamLogCategory["passwordManager"] = "passwordManager";
    BeamLogCategory["webAutofillInternal"] = "webAutofillInternal";
})(BeamLogCategory = exports.BeamLogCategory || (exports.BeamLogCategory = {}));
class BeamHTMLCollection {
    constructor(values) {
        this.values = values;
    }
    get length() {
        return this.values.length;
    }
    [Symbol.iterator]() {
        return this.values.values();
    }
    item(index) {
        return this.values[index];
    }
    namedItem(name) {
        return this.item(parseInt(name, 10));
    }
}
exports.BeamHTMLCollection = BeamHTMLCollection;


/***/ }),

/***/ "../../../Helpers/Utils/Web/BeamTypes/dist/src/BeamUIEvent.js":
/*!********************************************************************!*\
  !*** ../../../Helpers/Utils/Web/BeamTypes/dist/src/BeamUIEvent.js ***!
  \********************************************************************/
/***/ ((__unused_webpack_module, exports) => {

"use strict";

Object.defineProperty(exports, "__esModule", ({ value: true }));
exports.BeamUIEvent = void 0;
/**
 * We need this for tests as some properties of UIEvent (target) are readonly.
 */
class BeamUIEvent {
    preventDefault() {
        // TODO: Shouldn't we implement it?
    }
    stopPropagation() {
        // TODO: Shouldn't we implement it?
    }
}
exports.BeamUIEvent = BeamUIEvent;


/***/ }),

/***/ "../../../Helpers/Utils/Web/BeamTypes/dist/src/Native.js":
/*!***************************************************************!*\
  !*** ../../../Helpers/Utils/Web/BeamTypes/dist/src/Native.js ***!
  \***************************************************************/
/***/ ((__unused_webpack_module, exports) => {

"use strict";

Object.defineProperty(exports, "__esModule", ({ value: true }));
exports.Native = void 0;
class Native {
    /**
     * @param win {BeamWindow}
     */
    constructor(win, componentPrefix) {
        this.win = win;
        this.href = win.location.href;
        this.componentPrefix = componentPrefix;
        this.messageHandlers = win.webkit && win.webkit.messageHandlers;
        if (!this.messageHandlers) {
            throw Error("Could not find webkit message handlers");
        }
    }
    /**
     * @param win {BeamWindow}
     */
    static getInstance(win, componentPrefix) {
        if (!Native.instance) {
            Native.instance = new Native(win, componentPrefix);
        }
        return Native.instance;
    }
    /**
     * Message to the native part.
     *
     * @param name {string} Message name.
     *        Will be converted to ${prefix}_beam_${name} before sending.
     * @param payload {MessagePayload} The message data.
     *        An "href" property will always be added as the base URI of the current frame.
     */
    sendMessage(name, payload) {
        const messageKey = `${this.componentPrefix}_${name}`;
        const messageHandler = this.messageHandlers[messageKey];
        if (messageHandler) {
            const href = this.win.location.href;
            messageHandler.postMessage(Object.assign({ href }, payload), href);
        }
        else {
            throw Error(`No message handler for message "${messageKey}"`);
        }
    }
    toString() {
        return this.constructor.name;
    }
}
exports.Native = Native;


/***/ }),

/***/ "../../../Helpers/Utils/Web/BeamTypes/dist/src/index.js":
/*!**************************************************************!*\
  !*** ../../../Helpers/Utils/Web/BeamTypes/dist/src/index.js ***!
  \**************************************************************/
/***/ (function(__unused_webpack_module, exports, __webpack_require__) {

"use strict";

var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __exportStar = (this && this.__exportStar) || function(m, exports) {
    for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports, p)) __createBinding(exports, m, p);
};
Object.defineProperty(exports, "__esModule", ({ value: true }));
__exportStar(__webpack_require__(/*! ./BeamTypes */ "../../../Helpers/Utils/Web/BeamTypes/dist/src/BeamTypes.js"), exports);
__exportStar(__webpack_require__(/*! ./BeamKeyEvent */ "../../../Helpers/Utils/Web/BeamTypes/dist/src/BeamKeyEvent.js"), exports);
__exportStar(__webpack_require__(/*! ./BeamMouseEvent */ "../../../Helpers/Utils/Web/BeamTypes/dist/src/BeamMouseEvent.js"), exports);
__exportStar(__webpack_require__(/*! ./Native */ "../../../Helpers/Utils/Web/BeamTypes/dist/src/Native.js"), exports);
__exportStar(__webpack_require__(/*! ./BeamNamedNodeMap */ "../../../Helpers/Utils/Web/BeamTypes/dist/src/BeamNamedNodeMap.js"), exports);
__exportStar(__webpack_require__(/*! ./BeamUIEvent */ "../../../Helpers/Utils/Web/BeamTypes/dist/src/BeamUIEvent.js"), exports);
__exportStar(__webpack_require__(/*! ./BeamDOMRectList */ "../../../Helpers/Utils/Web/BeamTypes/dist/src/BeamDOMRectList.js"), exports);


/***/ }),

/***/ "../../../Helpers/Utils/Web/Utils/dist/src/BeamElementHelper.js":
/*!**********************************************************************!*\
  !*** ../../../Helpers/Utils/Web/Utils/dist/src/BeamElementHelper.js ***!
  \**********************************************************************/
/***/ ((__unused_webpack_module, exports, __webpack_require__) => {

"use strict";

Object.defineProperty(exports, "__esModule", ({ value: true }));
exports.BeamElementHelper = void 0;
const BeamRectHelper_1 = __webpack_require__(/*! ./BeamRectHelper */ "../../../Helpers/Utils/Web/Utils/dist/src/BeamRectHelper.js");
const BeamEmbedHelper_1 = __webpack_require__(/*! ./BeamEmbedHelper */ "../../../Helpers/Utils/Web/Utils/dist/src/BeamEmbedHelper.js");
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


/***/ }),

/***/ "../../../Helpers/Utils/Web/Utils/dist/src/BeamEmbedHelper.js":
/*!********************************************************************!*\
  !*** ../../../Helpers/Utils/Web/Utils/dist/src/BeamEmbedHelper.js ***!
  \********************************************************************/
/***/ ((__unused_webpack_module, exports, __webpack_require__) => {

"use strict";

Object.defineProperty(exports, "__esModule", ({ value: true }));
exports.BeamEmbedHelper = void 0;
const dequal_1 = __webpack_require__(/*! dequal */ "../../../../../.yarn/cache/dequal-npm-2.0.2-370927eb6c-86c7a2c59f.zip/node_modules/dequal/dist/index.js");
class BeamEmbedHelper {
    constructor(win) {
        this.embedPattern = "__EMBEDPATTERN__";
        this.win = win;
        this.embedRegex = new RegExp(this.embedPattern, "i");
        this.firstLocationLoaded = this.win.location;
    }
    /**
     * Returns true if element is Embed.
     *
     * @param {BeamElement} element
     * @param {BeamWindow} win
     * @return {*}  {boolean}
     * @memberof BeamEmbedHelper
     */
    isEmbeddableElement(element) {
        const isInsideIframe = this.isOnFullEmbeddablePage();
        // Check if current window location is matching embed url and is inside an iframe context
        if (isInsideIframe) {
            return isInsideIframe;
        }
        // check the element if it's embeddable
        switch (this.win.location.hostname) {
            case "twitter.com":
                return this.isTweet(element);
                break;
            case "www.youtube.com":
                return (this.isYouTubeThumbnail(element) ||
                    this.isEmbeddableIframe(element) ||
                    this.win.location.pathname.includes("/embed/"));
                break;
            default:
                return this.isEmbeddableIframe(element);
                break;
        }
    }
    getEmbeddableWindowLocation() {
        const urls = [this.win.location.href, this.firstLocationLoaded.href];
        if ((0, dequal_1.dequal)(urls, this.getEmbeddableWindowLocationLastUrls)) {
            return this.getEmbeddableWindowLocationLastResult;
        }
        const result = urls.find(url => {
            return this.embedRegex.test(url);
        });
        this.getEmbeddableWindowLocationLastUrls = urls;
        this.getEmbeddableWindowLocationLastResult = result;
        return result;
    }
    isOnFullEmbeddablePage() {
        return ((this.urlMatchesEmbedProvider([this.win.location.href, this.firstLocationLoaded.href])) &&
            this.isInsideIframe());
    }
    isEmbeddableIframe(element) {
        if (["iframe"].includes(element.tagName.toLowerCase())) {
            return this.urlMatchesEmbedProvider([element.src]);
        }
        return false;
    }
    urlMatchesEmbedProvider(urls) {
        if ((0, dequal_1.dequal)(urls, this.urlMatchesEmbedProviderLastUrls)) {
            return this.urlMatchesEmbedProviderLastResult;
        }
        const result = urls.some((url) => {
            if (!url)
                return false;
            return this.embedRegex.test(url) || url.includes("youtube.com/embed");
        });
        this.urlMatchesEmbedProviderLastUrls = urls;
        this.urlMatchesEmbedProviderLastResult = result;
        return result;
    }
    /**
     * Returns true if current window context is not the top level window context
     *
     * @return {*}  {boolean}
     * @memberof BeamEmbedHelper
     */
    isInsideIframe() {
        try {
            return window.self !== window.top;
        }
        catch (e) {
            return true;
        }
    }
    /**
     * Returns a url to the content to be inserted to the journal as embed.
     *
     * @param {BeamElement} element
     * @param {BeamWindow} win
     * @return {*}  {BeamHTMLElement}
     * @memberof this
     */
    parseElementForEmbed(element) {
        const { hostname } = this.win.location;
        switch (hostname) {
            case "twitter.com":
                // see if we target the tweet html
                return this.parseTwitterElementForEmbed(element);
                break;
            case "www.youtube.com":
                if (this.win.location.pathname.includes("/embed/")) {
                    const videoId = window.location.pathname.split("/").pop();
                    return this.createLinkElement(`https://www.youtube.com/watch?v=${videoId}`);
                }
                return this.parseYouTubeThumbnailForEmbed(element);
                break;
            default:
                if (element.src && this.urlMatchesEmbedProvider([element.src])) {
                    return this.createLinkElement(element.src);
                }
                break;
        }
    }
    /**
     * Convert element found on twitter.com to a anchor elemnt containing the tweet url.
     * returns undefined when element isn't a tweet
     *
     * @param {BeamElement} element
     * @param {BeamWindow<any>} win
     * @return {*}  {BeamHTMLElement}
     * @memberof this
     */
    parseTwitterElementForEmbed(element) {
        if (!this.isTweet(element)) {
            return;
        }
        // We are looking for a url like: <username>/status/1318584149247168513
        const linkElements = element.querySelectorAll("a[href*=\"/status/\"]");
        // return the href of the first element in NodeList
        const href = linkElements === null || linkElements === void 0 ? void 0 : linkElements[0].href;
        if (href) {
            return this.createLinkElement(href);
        }
        return;
    }
    /**
     * Returns if the provided element is a tweet. Should only be run on twitter.com
     *
     * @param {BeamElement} element
     * @return {*}  {boolean}
     * @memberof this
     */
    isTweet(element) {
        return element.getAttribute("data-testid") == "tweet";
    }
    /**
     * Returns if the provided element is a YouTube Thumbnail. Should only be run on youtube.com
     *
     * @param {BeamElement} element
     * @return {*}  {boolean}
     * @memberof this
     */
    isYouTubeThumbnail(element) {
        var _a, _b;
        const isThumb = Boolean((_a = element === null || element === void 0 ? void 0 : element.href) === null || _a === void 0 ? void 0 : _a.includes("/watch?v="));
        if (isThumb) {
            return true;
        }
        const parentLinkElement = this.hasParentOfType(element, "A", 5);
        return Boolean((_b = parentLinkElement === null || parentLinkElement === void 0 ? void 0 : parentLinkElement.href) === null || _b === void 0 ? void 0 : _b.includes("/watch?v="));
    }
    /**
     * Returns parent of node type. Maximum allowed recursive depth is 10
     *
     * @static
     * @param {BeamElement} node target node to start at
     * @param {string} type parent type to search for
     * @param {number} [count=10] maximum depth of recursion, defaults to 10
     * @return {*}  {(BeamElement | undefined)}
     * @memberof BeamEmbedHelper
     */
    hasParentOfType(element, type, count = 10) {
        if (count <= 0)
            return null;
        if (type !== "BODY" && (element === null || element === void 0 ? void 0 : element.tagName) === "BODY")
            return null;
        if (!(element === null || element === void 0 ? void 0 : element.parentElement))
            return null;
        if (type === (element === null || element === void 0 ? void 0 : element.tagName))
            return element;
        const newCount = count--;
        return this.hasParentOfType(element.parentElement, type, newCount);
    }
    /**
     * Parse html element into a Anchortag if it's a youtube thumbnail
     *
     * @param {BeamElement} element
     * @return {*}  {BeamHTMLElement}
     * @memberof this
     */
    parseYouTubeThumbnailForEmbed(element) {
        var _a, _b;
        if (!this.isYouTubeThumbnail(element)) {
            return;
        }
        // We are looking for a url like: /watch?v=DtC8Trc2Fe0
        if ((_a = element === null || element === void 0 ? void 0 : element.href) === null || _a === void 0 ? void 0 : _a.includes("/watch?v=")) {
            return this.createLinkElement(element === null || element === void 0 ? void 0 : element.href);
        }
        // Check parent link element
        const parentLinkElement = this.hasParentOfType(element, "A", 5);
        if ((_b = parentLinkElement === null || parentLinkElement === void 0 ? void 0 : parentLinkElement.href) === null || _b === void 0 ? void 0 : _b.includes("/watch?v=")) {
            return this.createLinkElement(parentLinkElement === null || parentLinkElement === void 0 ? void 0 : parentLinkElement.href);
        }
        return;
    }
    /**
     * Return BeamHTMLElement of an Anchortag with provided href attribute
     *
     * @param {string} href
     * @return {*}  {BeamHTMLElement}
     * @memberof this
     */
    createLinkElement(href) {
        const anchor = this.win.document.createElement("a");
        anchor.setAttribute("href", href);
        anchor.innerText = href;
        return anchor;
    }
}
exports.BeamEmbedHelper = BeamEmbedHelper;


/***/ }),

/***/ "../../../Helpers/Utils/Web/Utils/dist/src/BeamLogger.js":
/*!***************************************************************!*\
  !*** ../../../Helpers/Utils/Web/Utils/dist/src/BeamLogger.js ***!
  \***************************************************************/
/***/ ((__unused_webpack_module, exports, __webpack_require__) => {

"use strict";

Object.defineProperty(exports, "__esModule", ({ value: true }));
exports.BeamLogger = void 0;
const native_beamtypes_1 = __webpack_require__(/*! @beam/native-beamtypes */ "../../../Helpers/Utils/Web/BeamTypes/dist/src/index.js");
class BeamLogger {
    constructor(win, category) {
        const componentPrefix = "beam_logger";
        this.native = new native_beamtypes_1.Native(win, componentPrefix);
        this.category = category;
    }
    log(...args) {
        const formattedMessage = this.convertArgsToMessage(args);
        this.sendMessage(formattedMessage, native_beamtypes_1.BeamLogLevel.log);
    }
    logWarning(...args) {
        const formattedMessage = this.convertArgsToMessage(args);
        this.sendMessage(formattedMessage, native_beamtypes_1.BeamLogLevel.warning);
    }
    logDebug(...args) {
        const formattedMessage = this.convertArgsToMessage(args);
        this.sendMessage(formattedMessage, native_beamtypes_1.BeamLogLevel.debug);
    }
    logError(...args) {
        const formattedMessage = this.convertArgsToMessage(args);
        this.sendMessage(formattedMessage, native_beamtypes_1.BeamLogLevel.error);
    }
    sendMessage(message, level) {
        this.native.sendMessage("log", {
            message,
            level,
            category: this.category
        });
    }
    convertArgsToMessage(args) {
        const messageArgs = Object.values(args).map((value) => {
            let str;
            if (typeof value === "object") {
                try {
                    str = JSON.stringify(value);
                }
                catch (error) {
                    console.error(error);
                }
            }
            if (!str) {
                str = String(value);
            }
            return str;
        });
        return messageArgs
            .map((v) => v.substring(0, 3000)) // Limit msg to 3000 chars
            .join(", ");
    }
}
exports.BeamLogger = BeamLogger;


/***/ }),

/***/ "../../../Helpers/Utils/Web/Utils/dist/src/BeamRectHelper.js":
/*!*******************************************************************!*\
  !*** ../../../Helpers/Utils/Web/Utils/dist/src/BeamRectHelper.js ***!
  \*******************************************************************/
/***/ ((__unused_webpack_module, exports) => {

"use strict";

Object.defineProperty(exports, "__esModule", ({ value: true }));
exports.BeamRectHelper = void 0;
class BeamRectHelper {
    static filterRectArrayByRectArray(sourceArray, filterArray) {
        return sourceArray.filter((sourceRect) => {
            // When rect matches array return true to filter it
            return this.doRectMatchesRectsInArray(sourceRect, filterArray) == false;
        });
    }
    static doRectMatchesRectsInArray(sourceRect, filterArray) {
        return filterArray.some((filterRect) => {
            return this.doRectsMatch(sourceRect, filterRect);
        });
    }
    static doRectsMatch(rect1, rect2) {
        return (Math.round(rect1 === null || rect1 === void 0 ? void 0 : rect1.x) == Math.round(rect2 === null || rect2 === void 0 ? void 0 : rect2.x) &&
            Math.round(rect1 === null || rect1 === void 0 ? void 0 : rect1.y) == Math.round(rect2 === null || rect2 === void 0 ? void 0 : rect2.y) &&
            Math.round(rect1 === null || rect1 === void 0 ? void 0 : rect1.height) == Math.round(rect2 === null || rect2 === void 0 ? void 0 : rect2.height) &&
            Math.round(rect1 === null || rect1 === void 0 ? void 0 : rect1.width) == Math.round(rect2 === null || rect2 === void 0 ? void 0 : rect2.width));
    }
    /**
     * Return the bounding rectangle for two given rectangles
     *
     * @param rect1
     * @param rect2
     */
    static boundingRect(rect1, rect2) {
        const x = Math.min(rect1.x, rect2.x);
        const y = Math.min(rect1.y, rect2.y);
        const width = Math.max(rect1.x + rect1.width, rect2.x + rect2.width) - x;
        const height = Math.max(rect1.y + rect1.height, rect2.y + rect2.height) - y;
        return { x, y, width, height };
    }
    /**
     * Get the intersection of two given rectangles, the rectangles can have infinite dimensions
     * (for instance when `x` and `width` properties are respectively -Infinity and Infinity)
     *
     * @param rect1
     * @param rect2
     * @return {BeamRect} if the intersection is defined
     * @return undefined when no intersection exist
     */
    static intersection(rect1, rect2) {
        const x = Math.max(rect1.x, rect2.x);
        const y = Math.max(rect1.y, rect2.y);
        // rects can have Infinite dimensions, in which case have to filter out NaN values
        // since -Infinity + Infinity is NaN (rect.x + rect.width or rect.y + rect.height)
        const validX2 = [rect1.x + rect1.width, rect2.x + rect2.width].filter(v => !isNaN(v));
        const x2 = Math.min(...validX2);
        const validY2 = [rect1.y + rect1.height, rect2.y + rect2.height].filter(v => !isNaN(v));
        const y2 = Math.min(...validY2);
        if (x2 > x && y2 > y) {
            return { x, y, width: x2 - x, height: y2 - y };
        }
    }
}
exports.BeamRectHelper = BeamRectHelper;


/***/ }),

/***/ "../../../Helpers/Utils/Web/Utils/dist/src/PointAndShootHelper.js":
/*!************************************************************************!*\
  !*** ../../../Helpers/Utils/Web/Utils/dist/src/PointAndShootHelper.js ***!
  \************************************************************************/
/***/ ((__unused_webpack_module, exports, __webpack_require__) => {

"use strict";

Object.defineProperty(exports, "__esModule", ({ value: true }));
exports.PointAndShootHelper = void 0;
const native_beamtypes_1 = __webpack_require__(/*! @beam/native-beamtypes */ "../../../Helpers/Utils/Web/BeamTypes/dist/src/index.js");
const BeamElementHelper_1 = __webpack_require__(/*! ./BeamElementHelper */ "../../../Helpers/Utils/Web/Utils/dist/src/BeamElementHelper.js");
const BeamEmbedHelper_1 = __webpack_require__(/*! ./BeamEmbedHelper */ "../../../Helpers/Utils/Web/Utils/dist/src/BeamEmbedHelper.js");
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


/***/ }),

/***/ "../../../Helpers/Utils/Web/Utils/dist/src/index.js":
/*!**********************************************************!*\
  !*** ../../../Helpers/Utils/Web/Utils/dist/src/index.js ***!
  \**********************************************************/
/***/ ((__unused_webpack_module, exports, __webpack_require__) => {

"use strict";

Object.defineProperty(exports, "__esModule", ({ value: true }));
exports.PointAndShootHelper = exports.BeamElementHelper = exports.BeamEmbedHelper = exports.BeamRectHelper = exports.BeamLogger = void 0;
const BeamLogger_1 = __webpack_require__(/*! ./BeamLogger */ "../../../Helpers/Utils/Web/Utils/dist/src/BeamLogger.js");
Object.defineProperty(exports, "BeamLogger", ({ enumerable: true, get: function () { return BeamLogger_1.BeamLogger; } }));
const BeamRectHelper_1 = __webpack_require__(/*! ./BeamRectHelper */ "../../../Helpers/Utils/Web/Utils/dist/src/BeamRectHelper.js");
Object.defineProperty(exports, "BeamRectHelper", ({ enumerable: true, get: function () { return BeamRectHelper_1.BeamRectHelper; } }));
const BeamEmbedHelper_1 = __webpack_require__(/*! ./BeamEmbedHelper */ "../../../Helpers/Utils/Web/Utils/dist/src/BeamEmbedHelper.js");
Object.defineProperty(exports, "BeamEmbedHelper", ({ enumerable: true, get: function () { return BeamEmbedHelper_1.BeamEmbedHelper; } }));
const BeamElementHelper_1 = __webpack_require__(/*! ./BeamElementHelper */ "../../../Helpers/Utils/Web/Utils/dist/src/BeamElementHelper.js");
Object.defineProperty(exports, "BeamElementHelper", ({ enumerable: true, get: function () { return BeamElementHelper_1.BeamElementHelper; } }));
const PointAndShootHelper_1 = __webpack_require__(/*! ./PointAndShootHelper */ "../../../Helpers/Utils/Web/Utils/dist/src/PointAndShootHelper.js");
Object.defineProperty(exports, "PointAndShootHelper", ({ enumerable: true, get: function () { return PointAndShootHelper_1.PointAndShootHelper; } }));


/***/ }),

/***/ "./src/PasswordManager.ts":
/*!********************************!*\
  !*** ./src/PasswordManager.ts ***!
  \********************************/
/***/ ((__unused_webpack_module, exports, __webpack_require__) => {

"use strict";

Object.defineProperty(exports, "__esModule", ({ value: true }));
exports.PasswordManager = void 0;
const native_beamtypes_1 = __webpack_require__(/*! @beam/native-beamtypes */ "../../../Helpers/Utils/Web/BeamTypes/dist/src/index.js");
const native_utils_1 = __webpack_require__(/*! @beam/native-utils */ "../../../Helpers/Utils/Web/Utils/dist/src/index.js");
const PasswordManagerHelper_1 = __webpack_require__(/*! ./PasswordManagerHelper */ "./src/PasswordManagerHelper.ts");
const dequal_1 = __webpack_require__(/*! dequal */ "../../../../../.yarn/cache/dequal-npm-2.0.2-370927eb6c-86c7a2c59f.zip/node_modules/dequal/dist/index.js");
class PasswordManager {
    /**
     * @param win {(BeamWindow)}
     * @param ui {PasswordManagerUI}
     */
    constructor(win, ui) {
        this.ui = ui;
        this.textFields = [];
        this.win = win;
        this.logger = new native_utils_1.BeamLogger(win, native_beamtypes_1.BeamLogCategory.webAutofillInternal);
        this.passwordHelper = new PasswordManagerHelper_1.PasswordManagerHelper(win);
        this.win.addEventListener("load", this.onLoad.bind(this));
    }
    onLoad() {
        this.ui.load(document.URL);
    }
    /**
     * Installs window resize eventlistener and installs focus
     * and focusout eventlisteners on each element from the provided ids
     *
     * @param {string} ids_json
     * @memberof PasswordManager
     */
    installFocusHandlers(ids_json) {
        const ids = JSON.parse(ids_json);
        for (const id of ids) {
            // install handlers to all inputs
            const element = this.passwordHelper.getElementById(id);
            if (element) {
                element.addEventListener("focus", this.elementDidGainFocus.bind(this), false);
                element.addEventListener("focusout", this.elementDidLoseFocus.bind(this), false);
            }
        }
        this.win.addEventListener("resize", this.resize.bind(this));
    }
    resize(event) {
        // eslint-disable-next-line no-console
        console.log("resize!");
        if (event.target !== null) {
            this.ui.resize(this.win.innerWidth, this.win.innerHeight);
        }
    }
    elementDidGainFocus(event) {
        if (event.target !== null && this.passwordHelper.isTextField(event.target)) {
            const beamId = this.passwordHelper.getOrCreateBeamId(event.target);
            const text = event.target.value;
            this.ui.textInputReceivedFocus(beamId, text);
        }
    }
    elementDidLoseFocus(event) {
        if (event.target !== null && this.passwordHelper.isTextField(event.target)) {
            const beamId = this.passwordHelper.getOrCreateBeamId(event.target);
            this.ui.textInputLostFocus(beamId);
        }
    }
    /**
     * Installs eventhandler for submit events on form elements
     *
     * @memberof PasswordManager
     */
    installSubmitHandler() {
        const forms = document.getElementsByTagName("form");
        for (let e = 0; e < forms.length; e++) {
            const form = forms.item(e);
            form.addEventListener("submit", this.postSubmitMessage.bind(this));
        }
    }
    postSubmitMessage(event) {
        const beamId = this.passwordHelper.getOrCreateBeamId(event.target);
        this.ui.formSubmit(beamId);
    }
    sendTextFields(frameIdentifier) {
        if (frameIdentifier !== null) {
            this.passwordHelper.setFrameIdentifier(frameIdentifier);
            this.setupObserver();
        }
        this.handleTextFields();
    }
    setupObserver() {
        const observer = new MutationObserver(this.handleTextFields.bind(this));
        observer.observe(document, { childList: true, subtree: true });
    }
    handleTextFields() {
        const textFields = this.passwordHelper.getTextFieldsInDocument();
        if (!(0, dequal_1.dequal)(textFields, this.textFields)) {
            this.textFields = textFields;
            const textFieldsString = JSON.stringify(textFields);
            this.ui.sendTextFields(textFieldsString);
        }
    }
    toString() {
        return this.constructor.name;
    }
}
exports.PasswordManager = PasswordManager;


/***/ }),

/***/ "./src/PasswordManagerHelper.ts":
/*!**************************************!*\
  !*** ./src/PasswordManagerHelper.ts ***!
  \**************************************/
/***/ ((__unused_webpack_module, exports, __webpack_require__) => {

"use strict";

Object.defineProperty(exports, "__esModule", ({ value: true }));
exports.PasswordManagerHelper = void 0;
const native_utils_1 = __webpack_require__(/*! @beam/native-utils */ "../../../Helpers/Utils/Web/Utils/dist/src/index.js");
class PasswordManagerHelper {
    /**
     * @param win {(BeamWindow)}
     */
    constructor(win) {
        this.frameIdentifier = "";
        this.lastId = 0;
        this.win = win;
    }
    /**
     * Returns true if element is a textField element
     *
     * @param {*} element
     * @return {*}  {boolean}
     * @memberof Helpers
     */
    isTextField(element) {
        if (element === null) {
            return false;
        }
        if (element.getAttribute("list") !== null) {
            return false;
        }
        const elementType = element.getAttribute("type");
        return elementType === "text" || elementType === "password" || elementType === "email" || elementType === "number" || elementType === "tel" || elementType === "" || elementType === null;
    }
    /**
     * Returns true if element has no "disabled" attribute
     *
     * @param {*} element
     * @return {*}  {boolean}
     * @memberof Helpers
     */
    isEnabled(element) {
        if (element === null) {
            return false;
        }
        if ("disabled" in element.attributes) {
            return !element.disabled;
        }
        return true;
    }
    /**
     * Returns new unique identifier. The identifier is unique to the
     * window frame and each time this method is called the trailing
     * number is incremented.
     *
     * @return {*}  {string}
     * @memberof Helpers
     */
    makeBeamId() {
        this.lastId++;
        return "beam-" + this.frameIdentifier + "-" + this.lastId;
    }
    /**
     * returns true if provided element has a "data-beam-id" in
     * it's attributes.
     *
     * @param {*} element
     * @return {*}  {boolean}
     * @memberof Helpers
     */
    hasBeamId(element) {
        return "data-beam-id" in element.attributes;
    }
    /**
     * Returns the beam ID of the element. If no ID is found of the element
     * a unique ID will be created and assigned to the element attribute.
     *
     * @param {*} element
     * @return {*}  {string}
     * @memberof Helpers
     */
    getOrCreateBeamId(element) {
        if (this.hasBeamId(element)) {
            return element.dataset.beamId;
        }
        const beamId = this.makeBeamId();
        element.dataset.beamId = beamId;
        return beamId;
    }
    /**
     * Finds and returns element based on the beam ID
     *
     * @param {string} beamId
     * @return {*}  {}
     * @memberof Helpers
     */
    getElementById(beamId) {
        return document.querySelector("[data-beam-id='" + beamId + "']");
    }
    /**
     * Finds and returns all non-disabled text field elements in the document
     *
     * @return {*}  {Element[]}
     * @memberof Helpers
     */
    getTextFieldsInDocument() {
        const textFields = [];
        for (const tagName of ["input", "select", "textarea"]) {
            const inputElements = this.win.document.querySelectorAll(tagName);
            for (const element of inputElements) {
                if (this.isTextField(element) && this.isEnabled(element)) {
                    this.getOrCreateBeamId(element);
                    const attributes = element.attributes;
                    const textField = { tagName: element.tagName };
                    for (let a = 0; a < attributes.length; a++) {
                        const attr = attributes.item(a);
                        textField[attr.name] = attr.value;
                    }
                    textField["visible"] = native_utils_1.BeamElementHelper.isVisible(element, this.win);
                    textFields.push(textField);
                }
            }
        }
        return textFields;
    }
    getFocusedField() {
        var _a;
        return (_a = document.activeElement) === null || _a === void 0 ? void 0 : _a.getAttribute("data-beam-id");
    }
    getElementRects(ids_json) {
        const ids = JSON.parse(ids_json);
        const rects = ids.map(id => { var _a; return (_a = this.getElementById(id)) === null || _a === void 0 ? void 0 : _a.getBoundingClientRect(); });
        return JSON.stringify(rects);
    }
    getTextFieldValues(ids_json) {
        const ids = JSON.parse(ids_json);
        const values = ids.map(id => {
            const element = this.getElementById(id);
            return element.value;
        });
        return JSON.stringify(values);
    }
    setTextFieldValues(fields_json) {
        const fields = JSON.parse(fields_json);
        for (const field of fields) {
            const element = this.getElementById(field.id);
            if ((element === null || element === void 0 ? void 0 : element.tagName) == "INPUT") {
                const nativeInputValueSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set;
                nativeInputValueSetter.call(element, field.value);
                const event = new Event("input", { bubbles: true });
                // TODO: Fix this "simulated" value
                // event.simulated = true
                element.dispatchEvent(event);
                if (field.background) {
                    const styleAttribute = document.createAttribute("style");
                    styleAttribute.value = "background-color:" + field.background;
                    element.setAttributeNode(styleAttribute);
                }
                else {
                    const styleAttribute = element.getAttributeNode("style");
                    if (styleAttribute) {
                        element.removeAttributeNode(styleAttribute);
                    }
                }
            }
        }
    }
    togglePasswordFieldVisibility(fields_json, visibility) {
        const fields = JSON.parse(fields_json);
        for (const field of fields) {
            const passwordElement = this.getElementById(field.id);
            const elementType = passwordElement.getAttribute("type");
            if (elementType === "password" && (visibility == "true")) {
                passwordElement.setAttribute("type", "text");
            }
            if (elementType === "text" && (visibility == "false")) {
                passwordElement.setAttribute("type", "password");
            }
        }
    }
    setFrameIdentifier(frameIdentifier) {
        this.frameIdentifier = frameIdentifier;
    }
}
exports.PasswordManagerHelper = PasswordManagerHelper;


/***/ }),

/***/ "./src/PasswordManagerUI_native.ts":
/*!*****************************************!*\
  !*** ./src/PasswordManagerUI_native.ts ***!
  \*****************************************/
/***/ ((__unused_webpack_module, exports, __webpack_require__) => {

"use strict";

Object.defineProperty(exports, "__esModule", ({ value: true }));
exports.PasswordManagerUI_native = void 0;
const native_beamtypes_1 = __webpack_require__(/*! @beam/native-beamtypes */ "../../../Helpers/Utils/Web/BeamTypes/dist/src/index.js");
const native_utils_1 = __webpack_require__(/*! @beam/native-utils */ "../../../Helpers/Utils/Web/Utils/dist/src/index.js");
class PasswordManagerUI_native {
    /**
     * @param native {Native}
     */
    constructor(native) {
        this.native = native;
        this.logger = new native_utils_1.BeamLogger(this.native.win, native_beamtypes_1.BeamLogCategory.webAutofillInternal);
    }
    /**
     *
     * @param win {BeamWindow}
     * @returns {PasswordManagerUI_native}
     */
    static getInstance(win) {
        let instance;
        try {
            const native = native_beamtypes_1.Native.getInstance(win, "PasswordManager");
            instance = new PasswordManagerUI_native(native);
        }
        catch (e) {
            // eslint-disable-next-line no-console
            console.error(e);
            instance = null;
        }
        return instance;
    }
    load(url) {
        this.native.sendMessage("loaded", { url });
    }
    resize(width, height) {
        this.native.sendMessage("resize", { width, height });
    }
    textInputReceivedFocus(id, text) {
        this.native.sendMessage("textInputFocusIn", { id, text });
    }
    textInputLostFocus(id) {
        this.native.sendMessage("textInputFocusOut", { id });
    }
    formSubmit(id) {
        this.native.sendMessage("formSubmit", { id });
    }
    sendTextFields(textFieldsString) {
        this.native.sendMessage("textInputFields", { textFieldsString });
    }
    toString() {
        return this.constructor.name;
    }
}
exports.PasswordManagerUI_native = PasswordManagerUI_native;


/***/ })

/******/ 	});
/************************************************************************/
/******/ 	// The module cache
/******/ 	var __webpack_module_cache__ = {};
/******/ 	
/******/ 	// The require function
/******/ 	function __webpack_require__(moduleId) {
/******/ 		// Check if module is in cache
/******/ 		var cachedModule = __webpack_module_cache__[moduleId];
/******/ 		if (cachedModule !== undefined) {
/******/ 			return cachedModule.exports;
/******/ 		}
/******/ 		// Create a new module (and put it into the cache)
/******/ 		var module = __webpack_module_cache__[moduleId] = {
/******/ 			// no module.id needed
/******/ 			// no module.loaded needed
/******/ 			exports: {}
/******/ 		};
/******/ 	
/******/ 		// Execute the module function
/******/ 		__webpack_modules__[moduleId].call(module.exports, module, module.exports, __webpack_require__);
/******/ 	
/******/ 		// Return the exports of the module
/******/ 		return module.exports;
/******/ 	}
/******/ 	
/************************************************************************/
/******/ 	/* webpack/runtime/compat get default export */
/******/ 	(() => {
/******/ 		// getDefaultExport function for compatibility with non-harmony modules
/******/ 		__webpack_require__.n = (module) => {
/******/ 			var getter = module && module.__esModule ?
/******/ 				() => (module['default']) :
/******/ 				() => (module);
/******/ 			__webpack_require__.d(getter, { a: getter });
/******/ 			return getter;
/******/ 		};
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/define property getters */
/******/ 	(() => {
/******/ 		// define getter functions for harmony exports
/******/ 		__webpack_require__.d = (exports, definition) => {
/******/ 			for(var key in definition) {
/******/ 				if(__webpack_require__.o(definition, key) && !__webpack_require__.o(exports, key)) {
/******/ 					Object.defineProperty(exports, key, { enumerable: true, get: definition[key] });
/******/ 				}
/******/ 			}
/******/ 		};
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/hasOwnProperty shorthand */
/******/ 	(() => {
/******/ 		__webpack_require__.o = (obj, prop) => (Object.prototype.hasOwnProperty.call(obj, prop))
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/make namespace object */
/******/ 	(() => {
/******/ 		// define __esModule on exports
/******/ 		__webpack_require__.r = (exports) => {
/******/ 			if(typeof Symbol !== 'undefined' && Symbol.toStringTag) {
/******/ 				Object.defineProperty(exports, Symbol.toStringTag, { value: 'Module' });
/******/ 			}
/******/ 			Object.defineProperty(exports, '__esModule', { value: true });
/******/ 		};
/******/ 	})();
/******/ 	
/************************************************************************/
var __webpack_exports__ = {};
// This entry need to be wrapped in an IIFE because it need to be in strict mode.
(() => {
"use strict";
/*!**********************!*\
  !*** ./src/index.js ***!
  \**********************/
__webpack_require__.r(__webpack_exports__);
/* harmony import */ var _beam_native_beamtypes__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! @beam/native-beamtypes */ "../../../Helpers/Utils/Web/BeamTypes/dist/src/index.js");
/* harmony import */ var _beam_native_beamtypes__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(_beam_native_beamtypes__WEBPACK_IMPORTED_MODULE_0__);
/* harmony import */ var _PasswordManager__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./PasswordManager */ "./src/PasswordManager.ts");
/* harmony import */ var _PasswordManagerUI_native__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./PasswordManagerUI_native */ "./src/PasswordManagerUI_native.ts");




const native = _beam_native_beamtypes__WEBPACK_IMPORTED_MODULE_0__.Native.getInstance(window, "PasswordManager")
const PasswordManagerUI = new _PasswordManagerUI_native__WEBPACK_IMPORTED_MODULE_2__.PasswordManagerUI_native(native)

if (!window.beam) {
  window.beam = {}
}

window.beam.__ID__PasswordManager = new _PasswordManager__WEBPACK_IMPORTED_MODULE_1__.PasswordManager(window, PasswordManagerUI)

})();

/******/ })()
;
//# sourceMappingURL=data:application/json;charset=utf-8;base64,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V0FDQTtXQUNBOzs7OztXQ1BBOzs7OztXQ0FBO1dBQ0E7V0FDQTtXQUNBLHVEQUF1RCxpQkFBaUI7V0FDeEU7V0FDQSxnREFBZ0QsYUFBYTtXQUM3RDs7Ozs7Ozs7Ozs7Ozs7OztBQ04rQztBQUNFO0FBQ2tCOztBQUVuRSxlQUFlLHNFQUFrQjtBQUNqQyw4QkFBOEIsK0VBQXdCOztBQUV0RDtBQUNBO0FBQ0E7O0FBRUEsd0NBQXdDLDZEQUFlIiwic291cmNlcyI6WyJ3ZWJwYWNrOi8vQGJlYW0vbmF0aXZlLXBhc3N3b3JkbWFuYWdlci8uLi8uLi8uLi8uLi8uLi8ueWFybi9jYWNoZS9kZXF1YWwtbnBtLTIuMC4yLTM3MDkyN2ViNmMtODZjN2EyYzU5Zi56aXAvbm9kZV9tb2R1bGVzL2RlcXVhbC9kaXN0L2luZGV4LmpzIiwid2VicGFjazovL0BiZWFtL25hdGl2ZS1wYXNzd29yZG1hbmFnZXIvLi4vLi4vLi4vSGVscGVycy9VdGlscy9XZWIvQmVhbVR5cGVzL3NyYy9CZWFtRE9NUmVjdExpc3QudHMiLCJ3ZWJwYWNrOi8vQGJlYW0vbmF0aXZlLXBhc3N3b3JkbWFuYWdlci8uLi8uLi8uLi9IZWxwZXJzL1V0aWxzL1dlYi9CZWFtVHlwZXMvc3JjL0JlYW1LZXlFdmVudC50cyIsIndlYnBhY2s6Ly9AYmVhbS9uYXRpdmUtcGFzc3dvcmRtYW5hZ2VyLy4uLy4uLy4uL0hlbHBlcnMvVXRpbHMvV2ViL0JlYW1UeXBlcy9zcmMvQmVhbU1vdXNlRXZlbnQudHMiLCJ3ZWJwYWNrOi8vQGJlYW0vbmF0aXZlLXBhc3N3b3JkbWFuYWdlci8uLi8uLi8uLi9IZWxwZXJzL1V0aWxzL1dlYi9CZWFtVHlwZXMvc3JjL0JlYW1OYW1lZE5vZGVNYXAudHMiLCJ3ZWJwYWNrOi8vQGJlYW0vbmF0aXZlLXBhc3N3b3JkbWFuYWdlci8uLi8uLi8uLi9IZWxwZXJzL1V0aWxzL1dlYi9CZWFtVHlwZXMvc3JjL0JlYW1UeXBlcy50cyIsIndlYnBhY2s6Ly9AYmVhbS9uYXRpdmUtcGFzc3dvcmRtYW5hZ2VyLy4uLy4uLy4uL0hlbHBlcnMvVXRpbHMvV2ViL0JlYW1UeXBlcy9zcmMvQmVhbVVJRXZlbnQudHMiLCJ3ZWJwYWNrOi8vQGJlYW0vbmF0aXZlLXBhc3N3b3JkbWFuYWdlci8uLi8uLi8uLi9IZWxwZXJzL1V0aWxzL1dlYi9CZWFtVHlwZXMvc3JjL05hdGl2ZS50cyIsIndlYnBhY2s6Ly9AYmVhbS9uYXRpdmUtcGFzc3dvcmRtYW5hZ2VyLy4uLy4uLy4uL0hlbHBlcnMvVXRpbHMvV2ViL0JlYW1UeXBlcy9zcmMvaW5kZXgudHMiLCJ3ZWJwYWNrOi8vQGJlYW0vbmF0aXZlLXBhc3N3b3JkbWFuYWdlci8uLi8uLi8uLi9IZWxwZXJzL1V0aWxzL1dlYi9VdGlscy9zcmMvQmVhbUVsZW1lbnRIZWxwZXIudHMiLCJ3ZWJwYWNrOi8vQGJlYW0vbmF0aXZlLXBhc3N3b3JkbWFuYWdlci8uLi8uLi8uLi9IZWxwZXJzL1V0aWxzL1dlYi9VdGlscy9zcmMvQmVhbUVtYmVkSGVscGVyLnRzIiwid2VicGFjazovL0BiZWFtL25hdGl2ZS1wYXNzd29yZG1hbmFnZXIvLi4vLi4vLi4vSGVscGVycy9VdGlscy9XZWIvVXRpbHMvc3JjL0JlYW1Mb2dnZXIudHMiLCJ3ZWJwYWNrOi8vQGJlYW0vbmF0aXZlLXBhc3N3b3JkbWFuYWdlci8uLi8uLi8uLi9IZWxwZXJzL1V0aWxzL1dlYi9VdGlscy9zcmMvQmVhbVJlY3RIZWxwZXIudHMiLCJ3ZWJwYWNrOi8vQGJlYW0vbmF0aXZlLXBhc3N3b3JkbWFuYWdlci8uLi8uLi8uLi9IZWxwZXJzL1V0aWxzL1dlYi9VdGlscy9zcmMvUG9pbnRBbmRTaG9vdEhlbHBlci50cyIsIndlYnBhY2s6Ly9AYmVhbS9uYXRpdmUtcGFzc3dvcmRtYW5hZ2VyLy4uLy4uLy4uL0hlbHBlcnMvVXRpbHMvV2ViL1V0aWxzL3NyYy9pbmRleC50cyIsIndlYnBhY2s6Ly9AYmVhbS9uYXRpdmUtcGFzc3dvcmRtYW5hZ2VyLy4vc3JjL1Bhc3N3b3JkTWFuYWdlci50cyIsIndlYnBhY2s6Ly9AYmVhbS9uYXRpdmUtcGFzc3dvcmRtYW5hZ2VyLy4vc3JjL1Bhc3N3b3JkTWFuYWdlckhlbHBlci50cyIsIndlYnBhY2s6Ly9AYmVhbS9uYXRpdmUtcGFzc3dvcmRtYW5hZ2VyLy4vc3JjL1Bhc3N3b3JkTWFuYWdlclVJX25hdGl2ZS50cyIsIndlYnBhY2s6Ly9AYmVhbS9uYXRpdmUtcGFzc3dvcmRtYW5hZ2VyL3dlYnBhY2svYm9vdHN0cmFwIiwid2VicGFjazovL0BiZWFtL25hdGl2ZS1wYXNzd29yZG1hbmFnZXIvd2VicGFjay9ydW50aW1lL2NvbXBhdCBnZXQgZGVmYXVsdCBleHBvcnQiLCJ3ZWJwYWNrOi8vQGJlYW0vbmF0aXZlLXBhc3N3b3JkbWFuYWdlci93ZWJwYWNrL3J1bnRpbWUvZGVmaW5lIHByb3BlcnR5IGdldHRlcnMiLCJ3ZWJwYWNrOi8vQGJlYW0vbmF0aXZlLXBhc3N3b3JkbWFuYWdlci93ZWJwYWNrL3J1bnRpbWUvaGFzT3duUHJvcGVydHkgc2hvcnRoYW5kIiwid2VicGFjazovL0BiZWFtL25hdGl2ZS1wYXNzd29yZG1hbmFnZXIvd2VicGFjay9ydW50aW1lL21ha2UgbmFtZXNwYWNlIG9iamVjdCIsIndlYnBhY2s6Ly9AYmVhbS9uYXRpdmUtcGFzc3dvcmRtYW5hZ2VyLy4vc3JjL2luZGV4LmpzIl0sInNvdXJjZXNDb250ZW50IjpbInZhciBoYXMgPSBPYmplY3QucHJvdG90eXBlLmhhc093blByb3BlcnR5O1xuXG5mdW5jdGlvbiBmaW5kKGl0ZXIsIHRhciwga2V5KSB7XG5cdGZvciAoa2V5IG9mIGl0ZXIua2V5cygpKSB7XG5cdFx0aWYgKGRlcXVhbChrZXksIHRhcikpIHJldHVybiBrZXk7XG5cdH1cbn1cblxuZnVuY3Rpb24gZGVxdWFsKGZvbywgYmFyKSB7XG5cdHZhciBjdG9yLCBsZW4sIHRtcDtcblx0aWYgKGZvbyA9PT0gYmFyKSByZXR1cm4gdHJ1ZTtcblxuXHRpZiAoZm9vICYmIGJhciAmJiAoY3Rvcj1mb28uY29uc3RydWN0b3IpID09PSBiYXIuY29uc3RydWN0b3IpIHtcblx0XHRpZiAoY3RvciA9PT0gRGF0ZSkgcmV0dXJuIGZvby5nZXRUaW1lKCkgPT09IGJhci5nZXRUaW1lKCk7XG5cdFx0aWYgKGN0b3IgPT09IFJlZ0V4cCkgcmV0dXJuIGZvby50b1N0cmluZygpID09PSBiYXIudG9TdHJpbmcoKTtcblxuXHRcdGlmIChjdG9yID09PSBBcnJheSkge1xuXHRcdFx0aWYgKChsZW49Zm9vLmxlbmd0aCkgPT09IGJhci5sZW5ndGgpIHtcblx0XHRcdFx0d2hpbGUgKGxlbi0tICYmIGRlcXVhbChmb29bbGVuXSwgYmFyW2xlbl0pKTtcblx0XHRcdH1cblx0XHRcdHJldHVybiBsZW4gPT09IC0xO1xuXHRcdH1cblxuXHRcdGlmIChjdG9yID09PSBTZXQpIHtcblx0XHRcdGlmIChmb28uc2l6ZSAhPT0gYmFyLnNpemUpIHtcblx0XHRcdFx0cmV0dXJuIGZhbHNlO1xuXHRcdFx0fVxuXHRcdFx0Zm9yIChsZW4gb2YgZm9vKSB7XG5cdFx0XHRcdHRtcCA9IGxlbjtcblx0XHRcdFx0aWYgKHRtcCAmJiB0eXBlb2YgdG1wID09PSAnb2JqZWN0Jykge1xuXHRcdFx0XHRcdHRtcCA9IGZpbmQoYmFyLCB0bXApO1xuXHRcdFx0XHRcdGlmICghdG1wKSByZXR1cm4gZmFsc2U7XG5cdFx0XHRcdH1cblx0XHRcdFx0aWYgKCFiYXIuaGFzKHRtcCkpIHJldHVybiBmYWxzZTtcblx0XHRcdH1cblx0XHRcdHJldHVybiB0cnVlO1xuXHRcdH1cblxuXHRcdGlmIChjdG9yID09PSBNYXApIHtcblx0XHRcdGlmIChmb28uc2l6ZSAhPT0gYmFyLnNpemUpIHtcblx0XHRcdFx0cmV0dXJuIGZhbHNlO1xuXHRcdFx0fVxuXHRcdFx0Zm9yIChsZW4gb2YgZm9vKSB7XG5cdFx0XHRcdHRtcCA9IGxlblswXTtcblx0XHRcdFx0aWYgKHRtcCAmJiB0eXBlb2YgdG1wID09PSAnb2JqZWN0Jykge1xuXHRcdFx0XHRcdHRtcCA9IGZpbmQoYmFyLCB0bXApO1xuXHRcdFx0XHRcdGlmICghdG1wKSByZXR1cm4gZmFsc2U7XG5cdFx0XHRcdH1cblx0XHRcdFx0aWYgKCFkZXF1YWwobGVuWzFdLCBiYXIuZ2V0KHRtcCkpKSB7XG5cdFx0XHRcdFx0cmV0dXJuIGZhbHNlO1xuXHRcdFx0XHR9XG5cdFx0XHR9XG5cdFx0XHRyZXR1cm4gdHJ1ZTtcblx0XHR9XG5cblx0XHRpZiAoY3RvciA9PT0gQXJyYXlCdWZmZXIpIHtcblx0XHRcdGZvbyA9IG5ldyBVaW50OEFycmF5KGZvbyk7XG5cdFx0XHRiYXIgPSBuZXcgVWludDhBcnJheShiYXIpO1xuXHRcdH0gZWxzZSBpZiAoY3RvciA9PT0gRGF0YVZpZXcpIHtcblx0XHRcdGlmICgobGVuPWZvby5ieXRlTGVuZ3RoKSA9PT0gYmFyLmJ5dGVMZW5ndGgpIHtcblx0XHRcdFx0d2hpbGUgKGxlbi0tICYmIGZvby5nZXRJbnQ4KGxlbikgPT09IGJhci5nZXRJbnQ4KGxlbikpO1xuXHRcdFx0fVxuXHRcdFx0cmV0dXJuIGxlbiA9PT0gLTE7XG5cdFx0fVxuXG5cdFx0aWYgKEFycmF5QnVmZmVyLmlzVmlldyhmb28pKSB7XG5cdFx0XHRpZiAoKGxlbj1mb28uYnl0ZUxlbmd0aCkgPT09IGJhci5ieXRlTGVuZ3RoKSB7XG5cdFx0XHRcdHdoaWxlIChsZW4tLSAmJiBmb29bbGVuXSA9PT0gYmFyW2xlbl0pO1xuXHRcdFx0fVxuXHRcdFx0cmV0dXJuIGxlbiA9PT0gLTE7XG5cdFx0fVxuXG5cdFx0aWYgKCFjdG9yIHx8IHR5cGVvZiBmb28gPT09ICdvYmplY3QnKSB7XG5cdFx0XHRsZW4gPSAwO1xuXHRcdFx0Zm9yIChjdG9yIGluIGZvbykge1xuXHRcdFx0XHRpZiAoaGFzLmNhbGwoZm9vLCBjdG9yKSAmJiArK2xlbiAmJiAhaGFzLmNhbGwoYmFyLCBjdG9yKSkgcmV0dXJuIGZhbHNlO1xuXHRcdFx0XHRpZiAoIShjdG9yIGluIGJhcikgfHwgIWRlcXVhbChmb29bY3Rvcl0sIGJhcltjdG9yXSkpIHJldHVybiBmYWxzZTtcblx0XHRcdH1cblx0XHRcdHJldHVybiBPYmplY3Qua2V5cyhiYXIpLmxlbmd0aCA9PT0gbGVuO1xuXHRcdH1cblx0fVxuXG5cdHJldHVybiBmb28gIT09IGZvbyAmJiBiYXIgIT09IGJhcjtcbn1cblxuZXhwb3J0cy5kZXF1YWwgPSBkZXF1YWw7IiwiZXhwb3J0IGNsYXNzIEJlYW1ET01SZWN0TGlzdCBpbXBsZW1lbnRzIERPTVJlY3RMaXN0IHtcbiAgY29uc3RydWN0b3IocHJpdmF0ZSBsaXN0OiBET01SZWN0W10pIHtcbiAgfVxuXG4gIFtpbmRleDogbnVtYmVyXTogRE9NUmVjdFxuXG4gIGdldCBsZW5ndGgoKTogbnVtYmVyIHtcbiAgICByZXR1cm4gdGhpcy5saXN0Lmxlbmd0aFxuICB9XG5cbiAgW1N5bWJvbC5pdGVyYXRvcl0oKTogSXRlcmFibGVJdGVyYXRvcjxET01SZWN0PiB7XG4gICAgcmV0dXJuIHRoaXMubGlzdC52YWx1ZXMoKVxuICB9XG5cbiAgaXRlbShpbmRleDogbnVtYmVyKTogRE9NUmVjdCB8IG51bGwge1xuICAgIHJldHVybiB0aGlzLmxpc3RbaW5kZXhdXG4gIH1cbn1cbiIsImltcG9ydCB7QmVhbU1vdXNlRXZlbnR9IGZyb20gXCIuL0JlYW1Nb3VzZUV2ZW50XCJcblxuZXhwb3J0IGNsYXNzIEJlYW1LZXlFdmVudCBleHRlbmRzIEJlYW1Nb3VzZUV2ZW50IHtcbiAgY29uc3RydWN0b3IoYXR0cmlidXRlcyA9IHt9KSB7XG4gICAgc3VwZXIoKVxuICAgIE9iamVjdC5hc3NpZ24odGhpcywgYXR0cmlidXRlcylcbiAgfVxuXG4gIC8qKlxuICAgKiBUaGUga2V5IG5hbWVcbiAgICpcbiAgICogQHR5cGUgU3RyaW5nXG4gICAqL1xuICBrZXlcbn1cbiIsImltcG9ydCB7QmVhbVVJRXZlbnR9IGZyb20gXCIuL0JlYW1VSUV2ZW50XCJcblxuZXhwb3J0IGNsYXNzIEJlYW1Nb3VzZUV2ZW50IGV4dGVuZHMgQmVhbVVJRXZlbnQge1xuICBjb25zdHJ1Y3RvcihhdHRyaWJ1dGVzID0ge30pIHtcbiAgICBzdXBlcigpXG4gICAgT2JqZWN0LmFzc2lnbih0aGlzLCBhdHRyaWJ1dGVzKVxuICB9XG5cbiAgLyoqXG4gICAqIElmIHRoZSBPcHRpb24ga2V5IHdhcyBkb3duIGR1cmluZyB0aGUgZXZlbnQuXG4gICAqXG4gICAqIEB0eXBlIGJvb2xlYW5cbiAgICovXG4gIGFsdEtleVxuXG4gIC8qKlxuICAgKiBAdHlwZSBudW1iZXJcbiAgICovXG4gIGNsaWVudFhcblxuICAvKipcbiAgICogQHR5cGUgbnVtYmVyXG4gICAqL1xuICBjbGllbnRZXG59XG4iLCJleHBvcnQgY2xhc3MgQmVhbU5hbWVkTm9kZU1hcCBleHRlbmRzIE9iamVjdCBpbXBsZW1lbnRzIE5hbWVkTm9kZU1hcCB7XG4gIFtpbmRleDogbnVtYmVyXTogQXR0clxuXG4gIHByaXZhdGUgcmVhZG9ubHkgYXR0cnM6IEF0dHJbXSA9IFtdXG5cbiAgY29uc3RydWN0b3IocHJvcHMgPSB7fSkge1xuICAgIHN1cGVyKClcbiAgICBmb3IgKGNvbnN0IHAgaW4gcHJvcHMpIHtcbiAgICAgIGlmIChPYmplY3QucHJvdG90eXBlLmhhc093blByb3BlcnR5LmNhbGwocHJvcHMsIHApKSB7XG4gICAgICAgIGNvbnN0IGF0dHI6IEF0dHIgPSB7XG4gICAgICAgICAgQVRUUklCVVRFX05PREU6IDAsXG4gICAgICAgICAgQ0RBVEFfU0VDVElPTl9OT0RFOiAwLFxuICAgICAgICAgIENPTU1FTlRfTk9ERTogMCxcbiAgICAgICAgICBET0NVTUVOVF9GUkFHTUVOVF9OT0RFOiAwLFxuICAgICAgICAgIERPQ1VNRU5UX05PREU6IDAsXG4gICAgICAgICAgRE9DVU1FTlRfUE9TSVRJT05fQ09OVEFJTkVEX0JZOiAwLFxuICAgICAgICAgIERPQ1VNRU5UX1BPU0lUSU9OX0NPTlRBSU5TOiAwLFxuICAgICAgICAgIERPQ1VNRU5UX1BPU0lUSU9OX0RJU0NPTk5FQ1RFRDogMCxcbiAgICAgICAgICBET0NVTUVOVF9QT1NJVElPTl9GT0xMT1dJTkc6IDAsXG4gICAgICAgICAgRE9DVU1FTlRfUE9TSVRJT05fSU1QTEVNRU5UQVRJT05fU1BFQ0lGSUM6IDAsXG4gICAgICAgICAgRE9DVU1FTlRfUE9TSVRJT05fUFJFQ0VESU5HOiAwLFxuICAgICAgICAgIERPQ1VNRU5UX1RZUEVfTk9ERTogMCxcbiAgICAgICAgICBFTEVNRU5UX05PREU6IDAsXG4gICAgICAgICAgRU5USVRZX05PREU6IDAsXG4gICAgICAgICAgRU5USVRZX1JFRkVSRU5DRV9OT0RFOiAwLFxuICAgICAgICAgIE5PVEFUSU9OX05PREU6IDAsXG4gICAgICAgICAgUFJPQ0VTU0lOR19JTlNUUlVDVElPTl9OT0RFOiAwLFxuICAgICAgICAgIFRFWFRfTk9ERTogMCxcbiAgICAgICAgICBhZGRFdmVudExpc3RlbmVyKFxuICAgICAgICAgICAgICB0eXBlOiBzdHJpbmcsXG4gICAgICAgICAgICAgIGxpc3RlbmVyOiBFdmVudExpc3RlbmVyT3JFdmVudExpc3RlbmVyT2JqZWN0IHwgbnVsbCxcbiAgICAgICAgICAgICAgb3B0aW9uczogYm9vbGVhbiB8IEFkZEV2ZW50TGlzdGVuZXJPcHRpb25zIHwgdW5kZWZpbmVkXG4gICAgICAgICAgKTogdm9pZCB7XG4gICAgICAgICAgICAvLyBUT0RPOiBTaG91bGRuJ3Qgd2UgaW1wbGVtZW50IGl0P1xuICAgICAgICAgIH0sXG4gICAgICAgICAgYXBwZW5kQ2hpbGQ8VD4obmV3Q2hpbGQ6IFQpOiBUIHtcbiAgICAgICAgICAgIC8vIFRPRE86IFNob3VsZG4ndCB3ZSBpbXBsZW1lbnQgaXQ/XG4gICAgICAgICAgICByZXR1cm4gdW5kZWZpbmVkXG4gICAgICAgICAgfSxcbiAgICAgICAgICBiYXNlVVJJOiBcIlwiLFxuICAgICAgICAgIGNoaWxkTm9kZXM6IHVuZGVmaW5lZCxcbiAgICAgICAgICBjbG9uZU5vZGUoZGVlcDogYm9vbGVhbiB8IHVuZGVmaW5lZCk6IE5vZGUge1xuICAgICAgICAgICAgLy8gVE9ETzogU2hvdWxkbid0IHdlIGltcGxlbWVudCBpdD9cbiAgICAgICAgICAgIHJldHVybiB1bmRlZmluZWRcbiAgICAgICAgICB9LFxuICAgICAgICAgIGNvbXBhcmVEb2N1bWVudFBvc2l0aW9uKG90aGVyOiBOb2RlKTogbnVtYmVyIHtcbiAgICAgICAgICAgIHJldHVybiAwXG4gICAgICAgICAgfSxcbiAgICAgICAgICBjb250YWlucyhvdGhlcjogTm9kZSB8IG51bGwpOiBib29sZWFuIHtcbiAgICAgICAgICAgIHJldHVybiBmYWxzZVxuICAgICAgICAgIH0sXG4gICAgICAgICAgZGlzcGF0Y2hFdmVudChldmVudDogRXZlbnQpOiBib29sZWFuIHtcbiAgICAgICAgICAgIHJldHVybiBmYWxzZVxuICAgICAgICAgIH0sXG4gICAgICAgICAgZmlyc3RDaGlsZDogdW5kZWZpbmVkLFxuICAgICAgICAgIGdldFJvb3ROb2RlKG9wdGlvbnM6IEdldFJvb3ROb2RlT3B0aW9ucyB8IHVuZGVmaW5lZCk6IE5vZGUge1xuICAgICAgICAgICAgcmV0dXJuIHVuZGVmaW5lZFxuICAgICAgICAgIH0sXG4gICAgICAgICAgaGFzQ2hpbGROb2RlcygpOiBib29sZWFuIHtcbiAgICAgICAgICAgIHJldHVybiBmYWxzZVxuICAgICAgICAgIH0sXG4gICAgICAgICAgaW5zZXJ0QmVmb3JlPFQ+KG5ld0NoaWxkOiBULCByZWZDaGlsZDogTm9kZSB8IG51bGwpOiBUIHtcbiAgICAgICAgICAgIHJldHVybiB1bmRlZmluZWRcbiAgICAgICAgICB9LFxuICAgICAgICAgIGlzQ29ubmVjdGVkOiBmYWxzZSxcbiAgICAgICAgICBpc0RlZmF1bHROYW1lc3BhY2UobmFtZXNwYWNlOiBzdHJpbmcgfCBudWxsKTogYm9vbGVhbiB7XG4gICAgICAgICAgICByZXR1cm4gZmFsc2VcbiAgICAgICAgICB9LFxuICAgICAgICAgIGlzRXF1YWxOb2RlKG90aGVyTm9kZTogTm9kZSB8IG51bGwpOiBib29sZWFuIHtcbiAgICAgICAgICAgIHJldHVybiBmYWxzZVxuICAgICAgICAgIH0sXG4gICAgICAgICAgaXNTYW1lTm9kZShvdGhlck5vZGU6IE5vZGUgfCBudWxsKTogYm9vbGVhbiB7XG4gICAgICAgICAgICByZXR1cm4gZmFsc2VcbiAgICAgICAgICB9LFxuICAgICAgICAgIGxhc3RDaGlsZDogdW5kZWZpbmVkLFxuICAgICAgICAgIGxvb2t1cE5hbWVzcGFjZVVSSShwcmVmaXg6IHN0cmluZyB8IG51bGwpOiBzdHJpbmcgfCBudWxsIHtcbiAgICAgICAgICAgIHJldHVybiB1bmRlZmluZWRcbiAgICAgICAgICB9LFxuICAgICAgICAgIGxvb2t1cFByZWZpeChuYW1lc3BhY2U6IHN0cmluZyB8IG51bGwpOiBzdHJpbmcgfCBudWxsIHtcbiAgICAgICAgICAgIHJldHVybiB1bmRlZmluZWRcbiAgICAgICAgICB9LFxuICAgICAgICAgIG5hbWVzcGFjZVVSSTogdW5kZWZpbmVkLFxuICAgICAgICAgIG5leHRTaWJsaW5nOiB1bmRlZmluZWQsXG4gICAgICAgICAgbm9kZU5hbWU6IFwiXCIsXG4gICAgICAgICAgbm9kZVR5cGU6IDAsXG4gICAgICAgICAgbm9kZVZhbHVlOiB1bmRlZmluZWQsXG4gICAgICAgICAgb3duZXJEb2N1bWVudDogdW5kZWZpbmVkLFxuICAgICAgICAgIG93bmVyRWxlbWVudDogdW5kZWZpbmVkLFxuICAgICAgICAgIHBhcmVudEVsZW1lbnQ6IHVuZGVmaW5lZCxcbiAgICAgICAgICBwYXJlbnROb2RlOiB1bmRlZmluZWQsXG4gICAgICAgICAgcHJlZml4OiB1bmRlZmluZWQsXG4gICAgICAgICAgcHJldmlvdXNTaWJsaW5nOiB1bmRlZmluZWQsXG4gICAgICAgICAgcmVtb3ZlQ2hpbGQ8VD4ob2xkQ2hpbGQ6IFQpOiBUIHtcbiAgICAgICAgICAgIHJldHVybiB1bmRlZmluZWRcbiAgICAgICAgICB9LFxuICAgICAgICAgIHJlbW92ZUV2ZW50TGlzdGVuZXIoXG4gICAgICAgICAgICAgIHR5cGU6IHN0cmluZyxcbiAgICAgICAgICAgICAgY2FsbGJhY2s6IEV2ZW50TGlzdGVuZXJPckV2ZW50TGlzdGVuZXJPYmplY3QgfCBudWxsLFxuICAgICAgICAgICAgICBvcHRpb25zOiBFdmVudExpc3RlbmVyT3B0aW9ucyB8IGJvb2xlYW4gfCB1bmRlZmluZWRcbiAgICAgICAgICApOiB2b2lkIHtcbiAgICAgICAgICAgIC8vIFRPRE86IFNob3VsZG4ndCB3ZSBpbXBsZW1lbnQgaXQ/XG4gICAgICAgICAgfSxcbiAgICAgICAgICByZXBsYWNlQ2hpbGQ8VD4obmV3Q2hpbGQ6IE5vZGUsIG9sZENoaWxkOiBUKTogVCB7XG4gICAgICAgICAgICByZXR1cm4gdW5kZWZpbmVkXG4gICAgICAgICAgfSxcbiAgICAgICAgICBzcGVjaWZpZWQ6IGZhbHNlLFxuICAgICAgICAgIHRleHRDb250ZW50OiB1bmRlZmluZWQsXG4gICAgICAgICAgbm9ybWFsaXplKCk6IHZvaWQge1xuICAgICAgICAgICAgLy8gVE9ETzogU2hvdWxkbid0IHdlIGltcGxlbWVudCBpdD9cbiAgICAgICAgICB9LFxuICAgICAgICAgIG5hbWU6IHAsXG4gICAgICAgICAgbG9jYWxOYW1lOiBwLFxuICAgICAgICAgIHZhbHVlOiBwcm9wc1twXVxuICAgICAgICB9XG4gICAgICAgIHRoaXMuc2V0TmFtZWRJdGVtKGF0dHIpXG4gICAgICB9XG4gICAgfVxuICB9XG5cbiAgZ2V0IGxlbmd0aCgpOiBudW1iZXIge1xuICAgIHJldHVybiB0aGlzLmF0dHJzLmxlbmd0aFxuICB9XG5cbiAgZ2V0TmFtZWRJdGVtKHF1YWxpZmllZE5hbWU6IHN0cmluZyk6IEF0dHIgfCBudWxsIHtcbiAgICByZXR1cm4gdGhpcy5hdHRycy5maW5kKChhKSA9PiBhLmxvY2FsTmFtZSA9PT0gcXVhbGlmaWVkTmFtZSlcbiAgfVxuXG4gIGdldE5hbWVkSXRlbU5TKG5hbWVzcGFjZTogc3RyaW5nIHwgbnVsbCwgbG9jYWxOYW1lOiBzdHJpbmcpOiBBdHRyIHwgbnVsbCB7XG4gICAgcmV0dXJuIHRoaXMuZ2V0TmFtZWRJdGVtKGAke25hbWVzcGFjZX0uJHtsb2NhbE5hbWV9YClcbiAgfVxuXG4gIGl0ZW0oaW5kZXg6IG51bWJlcik6IEF0dHIgfCBudWxsIHtcbiAgICByZXR1cm4gdGhpcy5hdHRyc1tpbmRleF1cbiAgfVxuXG4gIHJlbW92ZU5hbWVkSXRlbShxdWFsaWZpZWROYW1lOiBzdHJpbmcpOiBBdHRyIHtcbiAgICBjb25zdCBvbGQgPSB0aGlzLmdldE5hbWVkSXRlbShxdWFsaWZpZWROYW1lKVxuICAgIGNvbnN0IGluZGV4ID0gdGhpcy5hdHRycy5pbmRleE9mKG9sZClcbiAgICB0aGlzLmF0dHJzLnNwbGljZShpbmRleCwgMSlcbiAgICByZXR1cm4gb2xkXG4gIH1cblxuICByZW1vdmVOYW1lZEl0ZW1OUyhuYW1lc3BhY2U6IHN0cmluZyB8IG51bGwsIGxvY2FsTmFtZTogc3RyaW5nKTogQXR0ciB7XG4gICAgcmV0dXJuIHRoaXMucmVtb3ZlTmFtZWRJdGVtKG5hbWVzcGFjZSArIFwiLlwiICsgbG9jYWxOYW1lKVxuICB9XG5cbiAgc2V0TmFtZWRJdGVtKGF0dHI6IEF0dHIpOiBBdHRyIHwgbnVsbCB7XG4gICAgY29uc3Qgb2xkID0gdGhpcy5nZXROYW1lZEl0ZW0oYXR0ci5sb2NhbE5hbWUpXG4gICAgaWYgKG9sZCkge1xuICAgICAgdGhpcy5yZW1vdmVOYW1lZEl0ZW0oYXR0ci5sb2NhbE5hbWUpXG4gICAgfVxuICAgIHRoaXMuYXR0cnMucHVzaChhdHRyKVxuICAgIHJldHVybiBvbGRcbiAgfVxuXG4gIHNldE5hbWVkSXRlbU5TKGF0dHI6IEF0dHIpOiBBdHRyIHwgbnVsbCB7XG4gICAgcmV0dXJuIHVuZGVmaW5lZFxuICB9XG5cbiAgW1N5bWJvbC5pdGVyYXRvcl0oKTogSXRlcmFibGVJdGVyYXRvcjxBdHRyPiB7XG4gICAgcmV0dXJuIHRoaXMuYXR0cnMudmFsdWVzKClcbiAgfVxuXG4gIHRvU3RyaW5nKCk6IHN0cmluZyB7XG4gICAgcmV0dXJuIHRoaXMuYXR0cnMubWFwKChhKSA9PiBgJHthLm5hbWV9PVwiJHthLnZhbHVlfVwiYCkuam9pbihcIiBcIilcbiAgfVxufVxuIiwiLypcbiAqIFR5cGVzIHVzZWQgYnkgQmVhbSBBUEkgKHRvIGV4Y2hhbmdlIG1lc3NhZ2VzLCB0eXBpY2FsbHkpLlxuICovXG5cbmV4cG9ydCBjbGFzcyBCZWFtU2l6ZSB7XG4gIGNvbnN0cnVjdG9yKHB1YmxpYyB3aWR0aDogbnVtYmVyLCBwdWJsaWMgaGVpZ2h0OiBudW1iZXIpIHt9XG59XG5cbmV4cG9ydCBlbnVtIE1lZGlhUGxheVN0YXRlIHtcbiAgcmVhZHkgPSBcInJlYWR5XCIsXG4gIHBsYXlpbmcgPSBcInBsYXlpbmdcIixcbiAgcGF1c2VkID0gXCJwYXVzZWRcIixcbiAgZW5kZWQgPSBcImVuZGVkXCIsXG59XG5cbmV4cG9ydCBpbnRlcmZhY2UgQmVhbU1lZGlhU3RhdGUge1xuICBwbGF5U3RhdGU6IE1lZGlhUGxheVN0YXRlXG4gIG11dGVkOiBib29sZWFuXG4gIHBpcFN1cHBvcnRlZDogYm9vbGVhblxuICBpc0luUGlwOiBib29sZWFuXG59XG5cbmV4cG9ydCBpbnRlcmZhY2UgQmVhbVJhbmdlR3JvdXAge1xuICBpZDogc3RyaW5nXG4gIHJhbmdlOiBCZWFtUmFuZ2VcbiAgdGV4dD86IHN0cmluZ1xufVxuXG5leHBvcnQgaW50ZXJmYWNlIEJlYW1TaG9vdEdyb3VwIHtcbiAgaWQ6IHN0cmluZ1xuICBlbGVtZW50OiBCZWFtSFRNTEVsZW1lbnRcbiAgdGV4dD86IHN0cmluZ1xufVxuXG5leHBvcnQgaW50ZXJmYWNlIEJlYW1FbGVtZW50Qm91bmRzIHtcbiAgZWxlbWVudDogQmVhbUhUTUxFbGVtZW50IHwgQmVhbUVsZW1lbnRcbiAgcmVjdDogQmVhbVJlY3Rcbn1cblxuZXhwb3J0IGludGVyZmFjZSBCZWFtVmlzdWFsVmlld3BvcnQge1xuICAvKipcbiAgICogQHR5cGUge251bWJlcn1cbiAgICovXG4gIG9mZnNldFRvcFxuXG4gIC8qKlxuICAgKiBAdHlwZSB7bnVtYmVyfVxuICAgKi9cbiAgcGFnZVRvcFxuXG4gIC8qKlxuICAgKiBAdHlwZSB7bnVtYmVyfVxuICAgKi9cbiAgb2Zmc2V0TGVmdFxuXG4gIC8qKlxuICAgKiBAdHlwZSB7bnVtYmVyfVxuICAgKi9cbiAgcGFnZUxlZnRcblxuICAvKipcbiAgICogQHR5cGUge251bWJlcn1cbiAgICovXG4gIHdpZHRoXG5cbiAgLyoqXG4gICAqIEB0eXBlIHtudW1iZXJ9XG4gICAqL1xuICBoZWlnaHRcblxuICBhZGRFdmVudExpc3RlbmVyKG5hbWUsIGNiKVxufVxuXG5leHBvcnQgaW50ZXJmYWNlIEJlYW1SZXNpemVJbmZvIHtcbiAgd2lkdGg6IG51bWJlclxuICBoZWlnaHQ6IG51bWJlclxufVxuXG5leHBvcnQgaW50ZXJmYWNlIEJlYW1FbWJlZENvbnRlbnRTaXplIHtcbiAgd2lkdGg6IG51bWJlclxuICBoZWlnaHQ6IG51bWJlclxufVxuXG5leHBvcnQgY2xhc3MgQmVhbVJlY3QgZXh0ZW5kcyBCZWFtU2l6ZSB7XG4gIGNvbnN0cnVjdG9yKHB1YmxpYyB4OiBudW1iZXIsIHB1YmxpYyB5OiBudW1iZXIsIHdpZHRoOiBudW1iZXIsIGhlaWdodDogbnVtYmVyKSB7XG4gICAgc3VwZXIod2lkdGgsIGhlaWdodClcbiAgfVxufVxuXG5leHBvcnQgY2xhc3MgTm90ZUluZm8ge1xuICAvKipcbiAgICogQHR5cGUgc3RyaW5nXG4gICAqL1xuICBpZCAvLyBTaG91bGQgbm90IGJlIG51bGxhYmxlIG9uY2Ugd2UgZ2V0IGl0XG5cbiAgLyoqXG4gICAqIEB0eXBlIHN0cmluZ1xuICAgKi9cbiAgdGl0bGVcbn1cblxuZXhwb3J0IHR5cGUgTWVzc2FnZVBheWxvYWQgPSBSZWNvcmQ8c3RyaW5nLCB1bmtub3duPlxuXG5leHBvcnQgaW50ZXJmYWNlIEJlYW1NZXNzYWdlSGFuZGxlciB7XG4gIHBvc3RNZXNzYWdlKG1lc3NhZ2U6IE1lc3NhZ2VQYXlsb2FkLCB0YXJnZXRPcmlnaW4/OiBzdHJpbmcsIHRyYW5zZmVyPzogVHJhbnNmZXJhYmxlW10pOiB2b2lkXG59XG5cbmV4cG9ydCB0eXBlIE1lc3NhZ2VIYW5kbGVycyA9IHtcbiAgW25hbWU6IHN0cmluZ106IEJlYW1NZXNzYWdlSGFuZGxlclxufVxuXG5leHBvcnQgaW50ZXJmYWNlIEJlYW1XZWJraXQ8TSA9IE1lc3NhZ2VIYW5kbGVycz4ge1xuICAvKipcbiAgICpcbiAgICovXG4gIG1lc3NhZ2VIYW5kbGVyczogTVxufVxuXG5leHBvcnQgaW50ZXJmYWNlIEJlYW1DcnlwdG8ge1xuICBnZXRSYW5kb21WYWx1ZXM6IGFueVxufVxuXG5leHBvcnQgaW50ZXJmYWNlIEJlYW1XaW5kb3c8TSA9IE1lc3NhZ2VIYW5kbGVycz4gZXh0ZW5kcyBCZWFtRXZlbnRUYXJnZXQge1xuICBvbnVubG9hZDogKCkgPT4gdm9pZFxuICBtYXRjaE1lZGlhKGFyZzA6IHN0cmluZylcbiAgY3J5cHRvOiBCZWFtQ3J5cHRvXG4gIGZyYW1lRWxlbWVudDogYW55XG4gIGZyYW1lczogQmVhbVdpbmRvd1tdXG4gIC8qKlxuICAgKiBAdHlwZSBzdHJpbmdcbiAgICovXG4gIG9yaWdpblxuXG4gIC8qKlxuICAgKiBAdHlwZSBCZWFtRG9jdW1lbnRcbiAgICovXG4gIHJlYWRvbmx5IGRvY3VtZW50OiBCZWFtRG9jdW1lbnRcblxuICAvKipcbiAgICogQHR5cGUgbnVtYmVyXG4gICAqL1xuICBzY3JvbGxZXG5cbiAgLyoqXG4gICAqIEB0eXBlIG51bWJlclxuICAgKi9cbiAgc2Nyb2xsWFxuXG4gIC8qKlxuICAgKiBAdHlwZSBudW1iZXJcbiAgICovXG4gIGlubmVyV2lkdGhcblxuICAvKipcbiAgICogQHR5cGUgbnVtYmVyXG4gICAqL1xuICBpbm5lckhlaWdodFxuXG4gIC8qKlxuICAgKiBAdHlwZSB7QmVhbVZpc3VhbFZpZXdwb3J0fVxuICAgKi9cbiAgdmlzdWFsVmlld3BvcnRcblxuICBsb2NhdGlvbjogQmVhbUxvY2F0aW9uXG5cbiAgd2Via2l0OiBCZWFtV2Via2l0PE0+XG5cbiAgc2Nyb2xsKHhDb29yZDogbnVtYmVyLCB5Q29vcmQ6IG51bWJlcik6IHZvaWRcblxuICBzY3JvbGxUbyh4Q29vcmQ6IG51bWJlciwgeUNvb3JkOiBudW1iZXIpXG5cbiAgZ2V0Q29tcHV0ZWRTdHlsZShlbDogQmVhbUVsZW1lbnQsIHBzZXVkbz86IHN0cmluZyk6IENTU1N0eWxlRGVjbGFyYXRpb25cblxuICBvcGVuKHVybD86IHN0cmluZywgbmFtZT86IHN0cmluZywgc3BlY3M/OiBzdHJpbmcsIHJlcGxhY2U/OiBib29sZWFuKTogQmVhbVdpbmRvdzxNPiB8IG51bGxcbn1cblxuZXhwb3J0IHR5cGUgQmVhbUxvY2F0aW9uID0gTG9jYXRpb25cblxuZXhwb3J0IGVudW0gQmVhbU5vZGVUeXBlIHtcbiAgZWxlbWVudCA9IDEsXG4gIHRleHQgPSAzLFxuICBwcm9jZXNzaW5nX2luc3RydWN0aW9uID0gNyxcbiAgY29tbWVudCA9IDgsXG4gIGRvY3VtZW50ID0gOSxcbiAgZG9jdW1lbnRfdHlwZSA9IDEwLFxuICBkb2N1bWVudF9mcmFnbWVudCA9IDExLFxufVxuXG5leHBvcnQgaW50ZXJmYWNlIEJlYW1FdmVudCB7XG4gIHJlYWRvbmx5IHR5cGU6IHN0cmluZ1xuICByZWFkb25seSBkZWZhdWx0UHJldmVudGVkOiBib29sZWFuXG59XG5cbmV4cG9ydCBpbnRlcmZhY2UgQmVhbUV2ZW50VGFyZ2V0PEUgZXh0ZW5kcyBCZWFtRXZlbnQgPSBCZWFtRXZlbnQ+IHtcbiAgYWRkRXZlbnRMaXN0ZW5lcih0eXBlOiBzdHJpbmcsIGNhbGxiYWNrOiAoZTogRSkgPT4gYW55LCBvcHRpb25zPzogYW55KVxuXG4gIHJlbW92ZUV2ZW50TGlzdGVuZXIodHlwZTogc3RyaW5nLCBjYWxsYmFjazogKGU6IEUpID0+IGFueSlcblxuICBkaXNwYXRjaEV2ZW50KGU6IEUpXG59XG5cbmV4cG9ydCB0eXBlIEJlYW1ET01SZWN0ID0gRE9NUmVjdFxuXG5leHBvcnQgZW51bSBCZWFtV2Via2l0UHJlc2VudGF0aW9uTW9kZSB7XG4gIGlubGluZSA9IFwiaW5saW5lXCIsIFxuICBmdWxsc2NyZWVuID0gXCJmdWxsc2NyZWVuXCIsXG4gIHBpcCA9IFwicGljdHVyZS1pbi1waWN0dXJlXCJcbn1cblxuZXhwb3J0IGludGVyZmFjZSBCZWFtTm9kZSBleHRlbmRzIEJlYW1FdmVudFRhcmdldCB7XG4gIGlzQ29ubmVjdGVkPzogYm9vbGVhblxuICBvZmZzZXRIZWlnaHQ6IG51bWJlclxuICBvZmZzZXRXaWR0aDogbnVtYmVyXG4gIHRleHRDb250ZW50OiBzdHJpbmdcbiAgbm9kZU5hbWU6IHN0cmluZ1xuICBub2RlVHlwZTogQmVhbU5vZGVUeXBlXG4gIGNoaWxkTm9kZXM6IEJlYW1Ob2RlW11cbiAgcGFyZW50Tm9kZT86IEJlYW1Ob2RlXG4gIHBhcmVudEVsZW1lbnQ/OiBCZWFtRWxlbWVudFxuICBtdXRlZD86IGJvb2xlYW5cbiAgcGF1c2VkPzogYm9vbGVhblxuICB3ZWJraXRTZXRQcmVzZW50YXRpb25Nb2RlKEJlYW1XZWJraXRQcmVzZW50YXRpb25Nb2RlKVxuXG4gIC8qKlxuICAgKiBNb2NrLXNwZWNpZmljIHByb3BlcnR5XG4gICAqIEBkZXByZWNhdGVkIE5vdCBiZWNhdXNlIGl0IHdpbGwgYmUgcmVtb3ZlZCwgYnV0IHRvIHdhcm4gYWJvdXQgbm9uLXN0YW5kYXJkLlxuICAgKi9cbiAgYm91bmRzOiBCZWFtUmVjdFxuXG4gIC8qKlxuICAgKiBAcGFyYW0gZWwge0hUTUxFbGVtZW50fVxuICAgKi9cbiAgYXBwZW5kQ2hpbGQoZWw6IEJlYW1FbGVtZW50KTogQmVhbU5vZGVcblxuICAvKipcbiAgICogQHBhcmFtIGVsIHtIVE1MRWxlbWVudH1cbiAgICovXG4gIHJlbW92ZUNoaWxkKGVsOiBCZWFtSFRNTEVsZW1lbnQpXG5cbiAgY29udGFpbnMoZWw6IEJlYW1Ob2RlKTogYm9vbGVhblxufVxuXG5leHBvcnQgaW50ZXJmYWNlIEJlYW1QYXJlbnROb2RlIGV4dGVuZHMgQmVhbU5vZGUge1xuICBjaGlsZHJlbjogQmVhbUhUTUxDb2xsZWN0aW9uXG59XG5cbmV4cG9ydCBpbnRlcmZhY2UgQmVhbUNoYXJhY3RlckRhdGEgZXh0ZW5kcyBCZWFtTm9kZSB7XG4gIGRhdGE6IHN0cmluZ1xufVxuXG5leHBvcnQgdHlwZSBCZWFtVGV4dCA9IEJlYW1DaGFyYWN0ZXJEYXRhXG5cbmV4cG9ydCBpbnRlcmZhY2UgQmVhbUVsZW1lbnQgZXh0ZW5kcyBCZWFtUGFyZW50Tm9kZSB7XG4gIGNsb25lTm9kZShhcmcwOiBib29sZWFuKTogQmVhbUVsZW1lbnRcbiAgcXVlcnlTZWxlY3RvckFsbChxdWVyeTogc3RyaW5nKTogQmVhbUVsZW1lbnRbXVxuICByZW1vdmVBdHRyaWJ1dGUocG9pbnREYXRhc2V0S2V5OiBhbnkpXG4gIGZvY3VzKClcbiAgZGF0YXNldDogYW55XG4gIGF0dHJpYnV0ZXM6IE5hbWVkTm9kZU1hcFxuICBzcmNzZXQ/OiBzdHJpbmdcbiAgY3VycmVudFNyYz86IHN0cmluZ1xuICBzcmM/OiBzdHJpbmdcbiAgaWQ/OiBzdHJpbmdcblxuICAvKipcbiAgICogQHR5cGUgc3RyaW5nXG4gICAqL1xuICBpbm5lckhUTUw6IHN0cmluZ1xuXG4gIG91dGVySFRNTDogc3RyaW5nXG5cbiAgY2xhc3NMaXN0OiBET01Ub2tlbkxpc3RcblxuICByZWFkb25seSBvZmZzZXRQYXJlbnQ6IEJlYW1FbGVtZW50XG5cbiAgcmVhZG9ubHkgcGFyZW50Tm9kZT86IEJlYW1Ob2RlXG4gIHJlYWRvbmx5IHBhcmVudEVsZW1lbnQ/OiBCZWFtRWxlbWVudFxuXG4gIC8qKlxuICAgKiBQYXJlbnQgcGFkZGluZy1yZWxhdGl2ZSB4IGNvb3JkaW5hdGUuXG4gICAqL1xuICBvZmZzZXRMZWZ0OiBudW1iZXJcblxuICAvKipcbiAgICogUGFyZW50IHBhZGRpbmctcmVsYXRpdmUgeSBjb29yZGluYXRlLlxuICAgKi9cbiAgb2Zmc2V0VG9wOiBudW1iZXJcblxuICAvKipcbiAgICogTGVmdCBib3JkZXIgd2lkdGhcbiAgICovXG4gIGNsaWVudExlZnQ6IG51bWJlclxuXG4gIC8qKlxuICAgKiBUb3AgYm9yZGVyIHdpZHRoXG4gICAqL1xuICBjbGllbnRUb3A6IG51bWJlclxuICBoZWlnaHQ6IG51bWJlclxuICB3aWR0aDogbnVtYmVyXG4gIHNjcm9sbExlZnQ6IG51bWJlclxuICBzY3JvbGxUb3A6IG51bWJlclxuICBzY3JvbGxIZWlnaHQ6IG51bWJlclxuICBzY3JvbGxXaWR0aDogbnVtYmVyXG4gIHRhZ05hbWU6IHN0cmluZ1xuICBocmVmOiBzdHJpbmdcbiAgZ2V0Q2xpZW50UmVjdHMoKTogRE9NUmVjdExpc3RcbiAgc2V0QXR0cmlidXRlKHF1YWxpZmllZE5hbWU6IHN0cmluZywgdmFsdWU6IHN0cmluZyk6IHZvaWRcbiAgZ2V0QXR0cmlidXRlKHF1YWxpZmllZE5hbWU6IHN0cmluZyk6IHN0cmluZyB8IG51bGxcblxuICAvKipcbiAgICogVmlld3BvcnQtcmVsYXRpdmUgcG9zaXRpb24uXG4gICAqL1xuICBnZXRCb3VuZGluZ0NsaWVudFJlY3QoKTogRE9NUmVjdFxufVxuXG5leHBvcnQgaW50ZXJmYWNlIEJlYW1FbGVtZW50Q1NTSW5saW5lU3R5bGUge1xuICBzdHlsZTogQ1NTU3R5bGVEZWNsYXJhdGlvblxufVxuXG5leHBvcnQgaW50ZXJmYWNlIEJlYW1IVE1MRWxlbWVudCBleHRlbmRzIEJlYW1FbGVtZW50LCBCZWFtRWxlbWVudENTU0lubGluZVN0eWxlIHtcbiAgaW5uZXJUZXh0OiBzdHJpbmdcbiAgbm9kZVZhbHVlOiBhbnlcbiAgZGF0YXNldDogUmVjb3JkPHN0cmluZywgc3RyaW5nPlxufVxuXG5leHBvcnQgaW50ZXJmYWNlIEJlYW1IVE1MSW5wdXRFbGVtZW50IGV4dGVuZHMgQmVhbUhUTUxFbGVtZW50IHtcbiAgdHlwZTogc3RyaW5nXG4gIHZhbHVlOiBzdHJpbmdcbn1cblxuZXhwb3J0IGludGVyZmFjZSBCZWFtSFRNTFRleHRBcmVhRWxlbWVudCBleHRlbmRzIEJlYW1IVE1MRWxlbWVudCB7XG4gIHZhbHVlOiBzdHJpbmdcbn1cblxuZXhwb3J0IGludGVyZmFjZSBCZWFtSFRNTElGcmFtZUVsZW1lbnQgZXh0ZW5kcyBCZWFtSFRNTEVsZW1lbnQge1xuICBzcmM6IHN0cmluZ1xufVxuXG5leHBvcnQgaW50ZXJmYWNlIEJlYW1Cb2R5IGV4dGVuZHMgQmVhbUhUTUxFbGVtZW50IHtcbiAgLyoqXG4gICAqIEB0eXBlIFN0cmluZ1xuICAgKi9cbiAgYmFzZVVSSVxuXG4gIC8qKlxuICAgKiBAdHlwZSBudW1iZXJcbiAgICovXG4gIHNjcm9sbFdpZHRoXG5cbiAgLyoqXG4gICAqIEB0eXBlIG51bWJlclxuICAgKi9cbiAgb2Zmc2V0V2lkdGhcblxuICAvKipcbiAgICogQHR5cGUgbnVtYmVyXG4gICAqL1xuICBjbGllbnRXaWR0aFxuXG4gIC8qKlxuICAgKiBAdHlwZSBudW1iZXJcbiAgICovXG4gIHNjcm9sbEhlaWdodFxuXG4gIC8qKlxuICAgKiBAdHlwZSBudW1iZXJcbiAgICovXG4gIG9mZnNldEhlaWdodFxuXG4gIC8qKlxuICAgKiBAdHlwZSBudW1iZXJcbiAgICovXG4gIGNsaWVudEhlaWdodFxufVxuXG5leHBvcnQgaW50ZXJmYWNlIEJlYW1SYW5nZSB7XG4gIGNvbW1vbkFuY2VzdG9yQ29udGFpbmVyOiBCZWFtTm9kZVxuICBjbG9uZUNvbnRlbnRzKCk6IERvY3VtZW50RnJhZ21lbnRcbiAgY2xvbmVSYW5nZSgpOiBCZWFtUmFuZ2VcbiAgY29sbGFwc2UodG9TdGFydD86IGJvb2xlYW4pOiB2b2lkXG4gIGNvbXBhcmVCb3VuZGFyeVBvaW50cyhob3c6IG51bWJlciwgc291cmNlUmFuZ2U6IEJlYW1SYW5nZSk6IG51bWJlclxuICBjb21wYXJlUG9pbnQobm9kZTogQmVhbU5vZGUsIG9mZnNldDogbnVtYmVyKTogbnVtYmVyXG4gIGNyZWF0ZUNvbnRleHR1YWxGcmFnbWVudChmcmFnbWVudDogc3RyaW5nKTogRG9jdW1lbnRGcmFnbWVudFxuICBkZWxldGVDb250ZW50cygpOiB2b2lkXG4gIGRldGFjaCgpOiB2b2lkXG4gIGV4dHJhY3RDb250ZW50cygpOiBEb2N1bWVudEZyYWdtZW50XG4gIGdldENsaWVudFJlY3RzKCk6IERPTVJlY3RMaXN0XG4gIGluc2VydE5vZGUobm9kZTogQmVhbU5vZGUpOiB2b2lkXG4gIGludGVyc2VjdHNOb2RlKG5vZGU6IEJlYW1Ob2RlKTogYm9vbGVhblxuICBpc1BvaW50SW5SYW5nZShub2RlOiBCZWFtTm9kZSwgb2Zmc2V0OiBudW1iZXIpOiBib29sZWFuXG4gIHNlbGVjdE5vZGVDb250ZW50cyhub2RlOiBCZWFtTm9kZSk6IHZvaWRcbiAgc2V0RW5kKG5vZGU6IEJlYW1Ob2RlLCBvZmZzZXQ6IG51bWJlcik6IHZvaWRcbiAgc2V0RW5kQWZ0ZXIobm9kZTogQmVhbU5vZGUpOiB2b2lkXG4gIHNldEVuZEJlZm9yZShub2RlOiBCZWFtTm9kZSk6IHZvaWRcbiAgc2V0U3RhcnQobm9kZTogQmVhbU5vZGUsIG9mZnNldDogbnVtYmVyKTogdm9pZFxuICBzZXRTdGFydEFmdGVyKG5vZGU6IEJlYW1Ob2RlKTogdm9pZFxuICBzZXRTdGFydEJlZm9yZShub2RlOiBCZWFtTm9kZSk6IHZvaWRcbiAgc3Vycm91bmRDb250ZW50cyhuZXdQYXJlbnQ6IEJlYW1Ob2RlKTogdm9pZFxuICB0b1N0cmluZygpOiBzdHJpbmdcbiAgRU5EX1RPX0VORDogbnVtYmVyXG4gIEVORF9UT19TVEFSVDogbnVtYmVyXG4gIFNUQVJUX1RPX0VORDogbnVtYmVyXG4gIFNUQVJUX1RPX1NUQVJUOiBudW1iZXJcbiAgY29sbGFwc2VkOiBib29sZWFuXG4gIGVuZENvbnRhaW5lcjogQmVhbU5vZGVcbiAgZW5kT2Zmc2V0OiBudW1iZXJcbiAgc3RhcnRDb250YWluZXI6IEJlYW1Ob2RlXG4gIHN0YXJ0T2Zmc2V0OiBudW1iZXJcbiAgc2VsZWN0Tm9kZShub2RlOiBCZWFtTm9kZSk6IHZvaWRcbiAgZ2V0Qm91bmRpbmdDbGllbnRSZWN0KCk6IERPTVJlY3Rcbn1cblxuZXhwb3J0IGRlY2xhcmUgY29uc3QgQmVhbVJhbmdlOiB7XG4gIHByb3RvdHlwZTogQmVhbVJhbmdlXG4gIG5ldyAoKTogQmVhbVJhbmdlXG4gIHJlYWRvbmx5IEVORF9UT19FTkQ6IG51bWJlclxuICByZWFkb25seSBFTkRfVE9fU1RBUlQ6IG51bWJlclxuICByZWFkb25seSBTVEFSVF9UT19FTkQ6IG51bWJlclxuICByZWFkb25seSBTVEFSVF9UT19TVEFSVDogbnVtYmVyXG4gIHRvU3RyaW5nKCk6IHN0cmluZ1xufVxuXG5leHBvcnQgaW50ZXJmYWNlIEJlYW1Eb2N1bWVudCBleHRlbmRzIEJlYW1Ob2RlIHtcbiAgY3JlYXRlRG9jdW1lbnRGcmFnbWVudCgpOiBhbnlcbiAgZWxlbWVudEZyb21Qb2ludCh4OiBhbnksIHk6IGFueSlcbiAgY3JlYXRlVHJlZVdhbGtlcihyb290OiBCZWFtTm9kZSwgd2hhdFRvU2hvdz86IG51bWJlciwgZmlsdGVyPzogTm9kZUZpbHRlciB8IG51bGwsIGV4cGFuZEVudGl0eVJlZmVyZW5jZXM/OiBib29sZWFuKTogVHJlZVdhbGtlcjtcbiAgY3JlYXRlVGV4dE5vZGUoZGF0YTogc3RyaW5nKTogVGV4dDtcbiAgLyoqXG4gICAqIEB0eXBlIHtIVE1MSHRtbEVsZW1lbnR9XG4gICAqL1xuICBkb2N1bWVudEVsZW1lbnRcblxuICBhY3RpdmVFbGVtZW50OiBCZWFtSFRNTEVsZW1lbnRcblxuICAvKipcbiAgICogQHR5cGUgQmVhbUJvZHlcbiAgICovXG4gIGJvZHk6IEJlYW1Cb2R5XG5cbiAgLyoqXG4gICAqIEBwYXJhbSB0YWcge3N0cmluZ31cbiAgICovXG4gIGNyZWF0ZUVsZW1lbnQodGFnKVxuXG4gIC8qKlxuICAgKiBAcmV0dXJuIHtCZWFtU2VsZWN0aW9ufVxuICAgKi9cbiAgZ2V0U2VsZWN0aW9uKClcblxuICAvKipcbiAgICogQHBhcmFtIHNlbGVjdG9yIHtzdHJpbmd9XG4gICAqIEByZXR1cm4ge0hUTUxFbGVtZW50W119XG4gICAqL1xuICBxdWVyeVNlbGVjdG9yQWxsKHNlbGVjdG9yOiBzdHJpbmcpOiBCZWFtTm9kZVtdXG5cbiAgLyoqXG4gICAqIEBwYXJhbSBzZWxlY3RvciB7c3RyaW5nfVxuICAgKiBAcmV0dXJuIHtIVE1MRWxlbWVudH1cbiAgICovXG4gIHF1ZXJ5U2VsZWN0b3Ioc2VsZWN0b3I6IHN0cmluZyk6IEJlYW1Ob2RlXG5cbiAgY3JlYXRlUmFuZ2UoKTogQmVhbVJhbmdlXG59XG5cbi8qKlxuICoge3gsIHl9IG9mIG1vdXNlIGxvY2F0aW9uXG4gKlxuICogQGV4cG9ydFxuICogQGludGVyZmFjZSBCZWFtTW91c2VMb2NhdGlvblxuICovXG5leHBvcnQgaW50ZXJmYWNlIEJlYW1Nb3VzZUxvY2F0aW9uIHtcbiAgeDogbnVtYmVyXG4gIHk6IG51bWJlclxufVxuXG5leHBvcnQgaW50ZXJmYWNlIEJlYW1TZWxlY3Rpb24ge1xuICBhbmNob3JOb2RlOiBCZWFtTm9kZVxuICBhbmNob3JPZmZzZXQ6IG51bWJlclxuICBmb2N1c05vZGU6IEJlYW1Ob2RlXG4gIGZvY3VzT2Zmc2V0OiBudW1iZXJcbiAgaXNDb2xsYXBzZWQ6IGJvb2xlYW5cbiAgcmFuZ2VDb3VudDogbnVtYmVyXG4gIHR5cGU6IHN0cmluZ1xuICBhZGRSYW5nZShyYW5nZTogQmVhbVJhbmdlKTogdm9pZFxuICBjb2xsYXBzZShub2RlOiBCZWFtTm9kZSwgb2Zmc2V0PzogbnVtYmVyKTogdm9pZFxuICBjb2xsYXBzZVRvRW5kKCk6IHZvaWRcbiAgY29sbGFwc2VUb1N0YXJ0KCk6IHZvaWRcbiAgY29udGFpbnNOb2RlKG5vZGU6IEJlYW1Ob2RlLCBhbGxvd1BhcnRpYWxDb250YWlubWVudD86IGJvb2xlYW4pOiBib29sZWFuXG4gIGRlbGV0ZUZyb21Eb2N1bWVudCgpOiB2b2lkXG4gIGVtcHR5KCk6IHZvaWRcbiAgZXh0ZW5kKG5vZGU6IEJlYW1Ob2RlLCBvZmZzZXQ/OiBudW1iZXIpOiB2b2lkXG4gIGdldFJhbmdlQXQoaW5kZXg6IG51bWJlcik6IEJlYW1SYW5nZVxuICByZW1vdmVBbGxSYW5nZXMoKTogdm9pZFxuICByZW1vdmVSYW5nZShyYW5nZTogQmVhbVJhbmdlKTogdm9pZFxuICBzZWxlY3RBbGxDaGlsZHJlbihub2RlOiBCZWFtTm9kZSk6IHZvaWRcbiAgc2V0QmFzZUFuZEV4dGVudChhbmNob3JOb2RlOiBCZWFtTm9kZSwgYW5jaG9yT2Zmc2V0OiBudW1iZXIsIGZvY3VzTm9kZTogQmVhbU5vZGUsIGZvY3VzT2Zmc2V0OiBudW1iZXIpOiB2b2lkXG4gIHNldFBvc2l0aW9uKG5vZGU6IEJlYW1Ob2RlLCBvZmZzZXQ/OiBudW1iZXIpOiB2b2lkXG4gIHRvU3RyaW5nKCk6IHN0cmluZ1xufVxuXG5leHBvcnQgaW50ZXJmYWNlIEJlYW1NdXRhdGlvblJlY29yZCB7XG4gIGFkZGVkTm9kZXM6IEJlYW1Ob2RlW11cbiAgYXR0cmlidXRlTmFtZTogc3RyaW5nXG4gIGF0dHJpYnV0ZU5hbWVzcGFjZTogc3RyaW5nXG4gIG5leHRTaWJsaW5nOiBCZWFtTm9kZVxuICBvbGRWYWx1ZTogc3RyaW5nXG4gIHByZXZpb3VzU2libGluZzogQmVhbU5vZGVcbiAgcmVtb3ZlZE5vZGVzOiBCZWFtTm9kZVtdXG4gIHRhcmdldDogQmVhbU5vZGVcbiAgdHlwZTogTXV0YXRpb25SZWNvcmRUeXBlXG59XG5cbmV4cG9ydCBjbGFzcyBCZWFtTXV0YXRpb25PYnNlcnZlciB7XG4gIGNvbnN0cnVjdG9yKHB1YmxpYyBmbikge1xuICAgIG5ldyBmbigpXG4gIH1cbiAgZGlzY29ubmVjdCgpOiB2b2lkIHtcbiAgICB0aHJvdyBuZXcgRXJyb3IoXCJNZXRob2Qgbm90IGltcGxlbWVudGVkLlwiKVxuICB9XG4gIG9ic2VydmUoX3RhcmdldDogQmVhbU5vZGUsIF9vcHRpb25zPzogTXV0YXRpb25PYnNlcnZlckluaXQpOiB2b2lkIHtcbiAgICB0aHJvdyBuZXcgRXJyb3IoXCJNZXRob2Qgbm90IGltcGxlbWVudGVkLlwiKVxuICB9XG4gIHRha2VSZWNvcmRzKCk6IEJlYW1NdXRhdGlvblJlY29yZFtdIHtcbiAgICB0aHJvdyBuZXcgRXJyb3IoXCJNZXRob2Qgbm90IGltcGxlbWVudGVkLlwiKVxuICB9XG59XG5cbmV4cG9ydCBjbGFzcyBCZWFtUmVzaXplT2JzZXJ2ZXIgaW1wbGVtZW50cyBSZXNpemVPYnNlcnZlciB7XG4gIGNvbnN0cnVjdG9yKCkge31cbiAgZGlzY29ubmVjdCgpOiB2b2lkIHtcbiAgICB0aHJvdyBuZXcgRXJyb3IoXCJNZXRob2Qgbm90IGltcGxlbWVudGVkLlwiKVxuICB9XG4gIG9ic2VydmUodGFyZ2V0OiBFbGVtZW50LCBvcHRpb25zPzogUmVzaXplT2JzZXJ2ZXJPcHRpb25zKTogdm9pZCB7XG4gICAgdGhyb3cgbmV3IEVycm9yKFwiTWV0aG9kIG5vdCBpbXBsZW1lbnRlZC5cIilcbiAgfVxuICB1bm9ic2VydmUodGFyZ2V0OiBFbGVtZW50KTogdm9pZCB7XG4gICAgdGhyb3cgbmV3IEVycm9yKFwiTWV0aG9kIG5vdCBpbXBsZW1lbnRlZC5cIilcbiAgfVxufVxuXG5leHBvcnQgaW50ZXJmYWNlIEJlYW1Db29yZGluYXRlcyB7XG4gIHg6IG51bWJlciBcbiAgeTogbnVtYmVyXG59XG5cbmV4cG9ydCBjbGFzcyBGcmFtZUluZm8ge1xuICAvKipcbiAgICovXG4gIGhyZWY6IHN0cmluZ1xuXG4gIC8qKlxuICAgKi9cbiAgYm91bmRzOiBCZWFtUmVjdFxuXG4gIHNjcm9sbFNpemU/OiBCZWFtRnJhbWVTY3JvbGxTaXppbmdcbn1cblxuZXhwb3J0IGludGVyZmFjZSBCZWFtRnJhbWVTY3JvbGxTaXppbmcge1xuICB3aWR0aDogbnVtYmVyXG4gIGhlaWdodDogbnVtYmVyXG59XG5cbmV4cG9ydCBlbnVtIEJlYW1Mb2dMZXZlbCB7XG4gIGxvZyA9IFwibG9nXCIsXG4gIHdhcm5pbmcgPSBcIndhcm5pbmdcIixcbiAgZXJyb3IgPSBcImVycm9yXCIsXG4gIGRlYnVnID0gXCJkZWJ1Z1wiXG59XG5cblxuZXhwb3J0IGVudW0gQmVhbUxvZ0NhdGVnb3J5IHtcbiAgZ2VuZXJhbCA9IFwiZ2VuZXJhbFwiLFxuICBwb2ludEFuZFNob290ID0gXCJwb2ludEFuZFNob290XCIsXG4gIGVtYmVkTm9kZSA9IFwiZW1iZWROb2RlXCIsXG4gIHdlYnBvc2l0aW9ucyA9IFwid2VicG9zaXRpb25zXCIsXG4gIG5hdmlnYXRpb24gPSBcIm5hdmlnYXRpb25cIixcbiAgbmF0aXZlID0gXCJuYXRpdmVcIixcbiAgcGFzc3dvcmRNYW5hZ2VyID0gXCJwYXNzd29yZE1hbmFnZXJcIixcbiAgd2ViQXV0b2ZpbGxJbnRlcm5hbCA9IFwid2ViQXV0b2ZpbGxJbnRlcm5hbFwiXG59XG5cbmV4cG9ydCBjbGFzcyBCZWFtSFRNTENvbGxlY3Rpb248RSBleHRlbmRzIEJlYW1FbGVtZW50ID0gQmVhbUVsZW1lbnQ+IC8qaW1wbGVtZW50cyBIVE1MQ29sbGVjdGlvbiovIHtcbiAgY29uc3RydWN0b3IocHJpdmF0ZSB2YWx1ZXM6IEVbXSkge1xuICB9XG5cbiAgW2luZGV4OiBudW1iZXJdOiBFXG5cbiAgZ2V0IGxlbmd0aCgpOiBudW1iZXIge1xuICAgIHJldHVybiB0aGlzLnZhbHVlcy5sZW5ndGhcbiAgfVxuXG4gIFtTeW1ib2wuaXRlcmF0b3JdKCk6IEl0ZXJhYmxlSXRlcmF0b3I8RT4ge1xuICAgIHJldHVybiB0aGlzLnZhbHVlcy52YWx1ZXMoKVxuICB9XG5cbiAgaXRlbShpbmRleDogbnVtYmVyKTogRSB8IG51bGwge1xuICAgIHJldHVybiB0aGlzLnZhbHVlc1tpbmRleF1cbiAgfVxuXG4gIG5hbWVkSXRlbShuYW1lOiBzdHJpbmcpOiBFIHwgbnVsbCB7XG4gICAgcmV0dXJuIHRoaXMuaXRlbShwYXJzZUludChuYW1lLCAxMCkpXG4gIH1cbn1cbiIsIi8qKlxuICogV2UgbmVlZCB0aGlzIGZvciB0ZXN0cyBhcyBzb21lIHByb3BlcnRpZXMgb2YgVUlFdmVudCAodGFyZ2V0KSBhcmUgcmVhZG9ubHkuXG4gKi9cbmV4cG9ydCBjbGFzcyBCZWFtVUlFdmVudCB7XG4gIC8qKlxuICAgKiBAdHlwZSBCZWFtSFRNTEVsZW1lbnRcbiAgICovXG4gIHRhcmdldFxuXG4gIHByZXZlbnREZWZhdWx0KCkge1xuICAgIC8vIFRPRE86IFNob3VsZG4ndCB3ZSBpbXBsZW1lbnQgaXQ/XG4gIH1cblxuICBzdG9wUHJvcGFnYXRpb24oKSB7XG4gICAgLy8gVE9ETzogU2hvdWxkbid0IHdlIGltcGxlbWVudCBpdD9cbiAgfVxufVxuIiwiaW1wb3J0IHtCZWFtV2luZG93LCBNZXNzYWdlUGF5bG9hZH0gZnJvbSBcIi4vQmVhbVR5cGVzXCJcblxuZXhwb3J0IGNsYXNzIE5hdGl2ZTxNPiB7XG4gIC8qKlxuICAgKiBTaW5nbGV0b25cbiAgICovXG4gIHN0YXRpYyBpbnN0YW5jZTogTmF0aXZlPGFueT5cbiAgd2luOiBCZWFtV2luZG93PE0+XG4gIHJlYWRvbmx5IGhyZWY6IHN0cmluZ1xuICByZWFkb25seSBjb21wb25lbnRQcmVmaXg6IHN0cmluZ1xuXG4gIHByb3RlY3RlZCByZWFkb25seSBtZXNzYWdlSGFuZGxlcnM6IE1cblxuICAvKipcbiAgICogQHBhcmFtIHdpbiB7QmVhbVdpbmRvd31cbiAgICovXG4gIHN0YXRpYyBnZXRJbnN0YW5jZTxNPih3aW46IEJlYW1XaW5kb3c8TT4sIGNvbXBvbmVudFByZWZpeDogc3RyaW5nKTogTmF0aXZlPE0+IHtcbiAgICBpZiAoIU5hdGl2ZS5pbnN0YW5jZSkge1xuICAgICAgTmF0aXZlLmluc3RhbmNlID0gbmV3IE5hdGl2ZTxNPih3aW4sIGNvbXBvbmVudFByZWZpeClcbiAgICB9XG4gICAgcmV0dXJuIE5hdGl2ZS5pbnN0YW5jZVxuICB9XG5cbiAgLyoqXG4gICAqIEBwYXJhbSB3aW4ge0JlYW1XaW5kb3d9XG4gICAqL1xuICBjb25zdHJ1Y3Rvcih3aW46IEJlYW1XaW5kb3c8TT4sIGNvbXBvbmVudFByZWZpeDogc3RyaW5nKSB7XG4gICAgdGhpcy53aW4gPSB3aW5cbiAgICB0aGlzLmhyZWYgPSB3aW4ubG9jYXRpb24uaHJlZlxuICAgIHRoaXMuY29tcG9uZW50UHJlZml4ID0gY29tcG9uZW50UHJlZml4XG4gICAgdGhpcy5tZXNzYWdlSGFuZGxlcnMgPSB3aW4ud2Via2l0ICYmIHdpbi53ZWJraXQubWVzc2FnZUhhbmRsZXJzIGFzIE1cbiAgICBpZiAoIXRoaXMubWVzc2FnZUhhbmRsZXJzKSB7XG4gICAgICB0aHJvdyBFcnJvcihcIkNvdWxkIG5vdCBmaW5kIHdlYmtpdCBtZXNzYWdlIGhhbmRsZXJzXCIpXG4gICAgfVxuICB9XG5cbiAgLyoqXG4gICAqIE1lc3NhZ2UgdG8gdGhlIG5hdGl2ZSBwYXJ0LlxuICAgKlxuICAgKiBAcGFyYW0gbmFtZSB7c3RyaW5nfSBNZXNzYWdlIG5hbWUuXG4gICAqICAgICAgICBXaWxsIGJlIGNvbnZlcnRlZCB0byAke3ByZWZpeH1fYmVhbV8ke25hbWV9IGJlZm9yZSBzZW5kaW5nLlxuICAgKiBAcGFyYW0gcGF5bG9hZCB7TWVzc2FnZVBheWxvYWR9IFRoZSBtZXNzYWdlIGRhdGEuXG4gICAqICAgICAgICBBbiBcImhyZWZcIiBwcm9wZXJ0eSB3aWxsIGFsd2F5cyBiZSBhZGRlZCBhcyB0aGUgYmFzZSBVUkkgb2YgdGhlIGN1cnJlbnQgZnJhbWUuXG4gICAqL1xuICBzZW5kTWVzc2FnZShuYW1lOiBzdHJpbmcsIHBheWxvYWQ6IE1lc3NhZ2VQYXlsb2FkKTogdm9pZCB7XG4gICAgY29uc3QgbWVzc2FnZUtleSA9IGAke3RoaXMuY29tcG9uZW50UHJlZml4fV8ke25hbWV9YFxuICAgIGNvbnN0IG1lc3NhZ2VIYW5kbGVyID0gdGhpcy5tZXNzYWdlSGFuZGxlcnNbbWVzc2FnZUtleV1cbiAgICBpZiAobWVzc2FnZUhhbmRsZXIpIHtcbiAgICAgIGNvbnN0IGhyZWYgPSB0aGlzLndpbi5sb2NhdGlvbi5ocmVmXG4gICAgICBtZXNzYWdlSGFuZGxlci5wb3N0TWVzc2FnZSh7aHJlZiwgLi4ucGF5bG9hZH0sIGhyZWYpXG4gICAgfSBlbHNlIHtcbiAgICAgIHRocm93IEVycm9yKGBObyBtZXNzYWdlIGhhbmRsZXIgZm9yIG1lc3NhZ2UgXCIke21lc3NhZ2VLZXl9XCJgKVxuICAgIH1cbiAgfVxuXG4gIHRvU3RyaW5nKCk6IHN0cmluZyB7XG4gICAgcmV0dXJuIHRoaXMuY29uc3RydWN0b3IubmFtZVxuICB9XG59XG4iLCJleHBvcnQgKiBmcm9tIFwiLi9CZWFtVHlwZXNcIlxuZXhwb3J0ICogZnJvbSBcIi4vQmVhbUtleUV2ZW50XCJcbmV4cG9ydCAqIGZyb20gXCIuL0JlYW1Nb3VzZUV2ZW50XCJcbmV4cG9ydCAqIGZyb20gXCIuL05hdGl2ZVwiXG5leHBvcnQgKiBmcm9tIFwiLi9CZWFtTmFtZWROb2RlTWFwXCJcbmV4cG9ydCAqIGZyb20gXCIuL0JlYW1VSUV2ZW50XCJcbmV4cG9ydCAqIGZyb20gXCIuL0JlYW1ET01SZWN0TGlzdFwiIiwiaW1wb3J0IHtcbiAgQmVhbUVsZW1lbnQsXG4gIEJlYW1IVE1MRWxlbWVudCxcbiAgQmVhbUhUTUxJbnB1dEVsZW1lbnQsXG4gIEJlYW1IVE1MVGV4dEFyZWFFbGVtZW50LFxuICBCZWFtUmVjdCxcbiAgQmVhbVdpbmRvd1xufSBmcm9tIFwiQGJlYW0vbmF0aXZlLWJlYW10eXBlc1wiXG5pbXBvcnQge0JlYW1SZWN0SGVscGVyfSBmcm9tIFwiLi9CZWFtUmVjdEhlbHBlclwiXG5pbXBvcnQgeyBCZWFtRW1iZWRIZWxwZXIgfSBmcm9tIFwiLi9CZWFtRW1iZWRIZWxwZXJcIlxuXG4vKipcbiAqIFVzZWZ1bCBtZXRob2RzIGZvciBIVE1MIEVsZW1lbnRzXG4gKi9cbmV4cG9ydCBjbGFzcyBCZWFtRWxlbWVudEhlbHBlciB7XG4gIHN0YXRpYyBnZXRBdHRyaWJ1dGUoYXR0cjogc3RyaW5nLCBlbGVtZW50OiBCZWFtRWxlbWVudCk6IHN0cmluZyB7XG4gICAgY29uc3QgYXR0cmlidXRlID0gZWxlbWVudC5hdHRyaWJ1dGVzLmdldE5hbWVkSXRlbShhdHRyKVxuICAgIHJldHVybiBhdHRyaWJ1dGU/LnZhbHVlXG4gIH1cblxuICBzdGF0aWMgZ2V0VHlwZShlbGVtZW50OiBCZWFtRWxlbWVudCk6IHN0cmluZyB7XG4gICAgcmV0dXJuIEJlYW1FbGVtZW50SGVscGVyLmdldEF0dHJpYnV0ZShcInR5cGVcIiwgZWxlbWVudClcbiAgfVxuXG4gIHN0YXRpYyBnZXRDb250ZW50RWRpdGFibGUoZWxlbWVudDogQmVhbUVsZW1lbnQpOiBzdHJpbmcge1xuICAgIHJldHVybiBCZWFtRWxlbWVudEhlbHBlci5nZXRBdHRyaWJ1dGUoXCJjb250ZW50ZWRpdGFibGVcIiwgZWxlbWVudCkgfHwgXCJpbmhlcml0XCJcbiAgfVxuXG4gIC8qKlxuICAgKiBSZXR1cm5zIGlmIGFuIGVsZW1lbnQgaXMgYSB0ZXh0YXJlYSBvciBhbiBpbnB1dCBlbGVtZW50cyB3aXRoIGEgdGV4dFxuICAgKiBiYXNlZCBpbnB1dCB0eXBlICh0ZXh0LCBlbWFpbCwgZGF0ZSwgbnVtYmVyLi4uKVxuICAgKlxuICAgKiBAcGFyYW0gZWxlbWVudCB7QmVhbUhUTUxFbGVtZW50fSBUaGUgRE9NIEVsZW1lbnQgdG8gY2hlY2suXG4gICAqIEByZXR1cm4gSWYgdGhlIGVsZW1lbnQgaXMgc29tZSBraW5kIG9mIHRleHQgaW5wdXQuXG4gICAqL1xuICBzdGF0aWMgaXNUZXh0dWFsSW5wdXRUeXBlKGVsZW1lbnQ6IEJlYW1IVE1MRWxlbWVudCk6IGJvb2xlYW4ge1xuICAgIGNvbnN0IHRhZyA9IGVsZW1lbnQudGFnTmFtZS50b0xvd2VyQ2FzZSgpXG4gICAgaWYgKHRhZyA9PT0gXCJ0ZXh0YXJlYVwiKSB7XG4gICAgICByZXR1cm4gdHJ1ZVxuICAgIH0gZWxzZSBpZiAodGFnID09PSBcImlucHV0XCIpIHtcbiAgICAgIGNvbnN0IHR5cGVzID0gW1xuICAgICAgICBcInRleHRcIiwgXCJlbWFpbFwiLCBcInBhc3N3b3JkXCIsXG4gICAgICAgIFwiZGF0ZVwiLCBcImRhdGV0aW1lLWxvY2FsXCIsIFwibW9udGhcIixcbiAgICAgICAgXCJudW1iZXJcIiwgXCJzZWFyY2hcIiwgXCJ0ZWxcIixcbiAgICAgICAgXCJ0aW1lXCIsIFwidXJsXCIsIFwid2Vla1wiLFxuICAgICAgICAvLyBmb3IgbGVnYWN5IHN1cHBvcnRcbiAgICAgICAgXCJkYXRldGltZVwiXG4gICAgICBdXG4gICAgICByZXR1cm4gdHlwZXMuaW5jbHVkZXMoKGVsZW1lbnQgYXMgQmVhbUhUTUxJbnB1dEVsZW1lbnQpLnR5cGUpXG4gICAgfVxuICAgIHJldHVybiBmYWxzZVxuICB9XG5cbiAgLyoqXG4gICAqIFJldHVybnMgdGhlIHRleHQgdmFsdWUgZm9yIGEgZ2l2ZW4gZWxlbWVudCwgdGV4dCB2YWx1ZSBtZWFuaW5nIGVpdGhlclxuICAgKiB0aGUgZWxlbWVudCdzIGlubmVyVGV4dCBvciB0aGUgaW5wdXQgdmFsdWVcbiAgICpcbiAgICogQHBhcmFtIGVsXG4gICAqL1xuICBzdGF0aWMgZ2V0VGV4dFZhbHVlKGVsOiBCZWFtRWxlbWVudCk6IHN0cmluZyB7XG4gICAgbGV0IHRleHRWYWx1ZVxuICAgIGNvbnN0IHRhZ05hbWUgPSBlbC50YWdOYW1lLnRvTG93ZXJDYXNlKClcbiAgICBzd2l0Y2ggKHRhZ05hbWUpIHtcbiAgICAgIGNhc2UgXCJpbnB1dFwiOiB7XG4gICAgICAgIGNvbnN0IGlucHV0RWwgPSBlbCBhcyBCZWFtSFRNTElucHV0RWxlbWVudFxuICAgICAgICBpZiAoQmVhbUVsZW1lbnRIZWxwZXIuaXNUZXh0dWFsSW5wdXRUeXBlKGlucHV0RWwpKSB7XG4gICAgICAgICAgdGV4dFZhbHVlID0gaW5wdXRFbC52YWx1ZVxuICAgICAgICB9XG4gICAgICB9XG4gICAgICAgIGJyZWFrXG4gICAgICBjYXNlIFwidGV4dGFyZWFcIjpcbiAgICAgICAgdGV4dFZhbHVlID0gKGVsIGFzIEJlYW1IVE1MVGV4dEFyZWFFbGVtZW50KS52YWx1ZVxuICAgICAgICBicmVha1xuICAgICAgZGVmYXVsdDpcbiAgICAgICAgdGV4dFZhbHVlID0gKGVsIGFzIEJlYW1IVE1MRWxlbWVudCkuaW5uZXJUZXh0XG4gICAgfVxuICAgIHJldHVybiB0ZXh0VmFsdWVcbiAgfVxuXG4gIHN0YXRpYyBnZXRCYWNrZ3JvdW5kSW1hZ2VVUkwoZWxlbWVudDogQmVhbUVsZW1lbnQsIHdpbjogQmVhbVdpbmRvdyk6IHN0cmluZyB8IG51bGwge1xuICAgIGNvbnN0IHN0eWxlID0gd2luLmdldENvbXB1dGVkU3R5bGU/LihlbGVtZW50KVxuICAgIGNvbnN0IG1hdGNoQXJyYXkgPSBzdHlsZT8uYmFja2dyb3VuZEltYWdlLm1hdGNoKC91cmxcXCgoW14pXSspLylcbiAgICBpZiAobWF0Y2hBcnJheSAmJiBtYXRjaEFycmF5Lmxlbmd0aCA+IDEpIHtcbiAgICAgIHJldHVybiBtYXRjaEFycmF5WzFdLnJlcGxhY2UoLygnfFwiKS9nLFwiXCIpXG4gICAgfVxuICB9XG5cbiAgLyoqXG4gICAqIFJldHVybnMgcGFyZW50IG9mIG5vZGUgdHlwZS4gTWF4aW11bSBhbGxvd2VkIHJlY3Vyc2l2ZSBkZXB0aCBpcyAxMFxuICAgKlxuICAgKiBAc3RhdGljXG4gICAqIEBwYXJhbSB7QmVhbUVsZW1lbnR9IG5vZGUgdGFyZ2V0IG5vZGUgdG8gc3RhcnQgYXRcbiAgICogQHBhcmFtIHtzdHJpbmd9IHR5cGUgcGFyZW50IHR5cGUgdG8gc2VhcmNoIGZvclxuICAgKiBAcGFyYW0ge251bWJlcn0gW2NvdW50PTEwXSBtYXhpbXVtIGRlcHRoIG9mIHJlY3Vyc2lvbiwgZGVmYXVsdHMgdG8gMTBcbiAgICogQHJldHVybiB7Kn0gIHsoQmVhbUVsZW1lbnQgfCB1bmRlZmluZWQpfVxuICAgKiBAbWVtYmVyb2YgQmVhbUVsZW1lbnRIZWxwZXJcbiAgICovXG4gIHN0YXRpYyBoYXNQYXJlbnRPZlR5cGUoZWxlbWVudDogQmVhbUVsZW1lbnQsIHR5cGU6IHN0cmluZywgY291bnQgPSAxMCk6IEJlYW1FbGVtZW50IHwgdW5kZWZpbmVkIHtcbiAgICBpZiAoY291bnQgPD0gMCkgcmV0dXJuIG51bGxcbiAgICBpZiAodHlwZSAhPT0gXCJCT0RZXCIgJiYgZWxlbWVudD8udGFnTmFtZSA9PT0gXCJCT0RZXCIpIHJldHVybiBudWxsXG4gICAgaWYgKCFlbGVtZW50Py5wYXJlbnRFbGVtZW50KSByZXR1cm4gbnVsbFxuICAgIGlmICh0eXBlID09PSBlbGVtZW50Py50YWdOYW1lKSByZXR1cm4gZWxlbWVudFxuICAgIGNvbnN0IG5ld0NvdW50ID0gY291bnQtLVxuICAgIHJldHVybiBCZWFtRWxlbWVudEhlbHBlci5oYXNQYXJlbnRPZlR5cGUoZWxlbWVudC5wYXJlbnRFbGVtZW50LCB0eXBlLCBuZXdDb3VudClcbiAgfVxuICAvKipcbiAgICogUGFyc2UgRWxlbWVudCBiYXNlZCBvbiBpdCdzIHN0eWxlcyBhbmQgc3RydWN0dXJlLiBJbmNsdWRlZCBjb252ZXJzaW9uczpcbiAgICogLSBDb252ZXJ0IGJhY2tncm91bmQgaW1hZ2UgZWxlbWVudCB0byBpbWcgZWxlbWVudFxuICAgKiAtIFdyYXBwaW5nIGVsZW1lbnQgaW4gYW5jaG9yIGlmIHBhcmVudCBpcyBhbmNob3IgdGFnXG4gICAqXG4gICAqIEBzdGF0aWNcbiAgICogQHBhcmFtIHtCZWFtRWxlbWVudH0gZWxlbWVudFxuICAgKiBAcGFyYW0ge0JlYW1XaW5kb3c8YW55Pn0gd2luXG4gICAqIEByZXR1cm4geyp9ICB7QmVhbUhUTUxFbGVtZW50fVxuICAgKiBAbWVtYmVyb2YgQmVhbUVsZW1lbnRIZWxwZXJcbiAgICovXG4gIHN0YXRpYyBwYXJzZUVsZW1lbnRCYXNlZE9uU3R5bGVzKGVsZW1lbnQ6IEJlYW1FbGVtZW50LCB3aW46IEJlYW1XaW5kb3c8YW55Pik6IEJlYW1IVE1MRWxlbWVudCB7XG4gICAgY29uc3QgZW1iZWRIZWxwZXIgPSBuZXcgQmVhbUVtYmVkSGVscGVyKHdpbilcbiAgICAvLyBJZiB3ZSBzdXBwb3J0IGVtYmVkZGluZyBvbiB0aGUgY3VycmVudCBsb2NhdGlvblxuICAgIGlmIChlbWJlZEhlbHBlci5pc0VtYmVkZGFibGVFbGVtZW50KGVsZW1lbnQpKSB7XG4gICAgICAvLyBwYXJzZSB0aGUgZWxlbWVudCBmb3IgZW1iZWRkaW5nLlxuICAgICAgY29uc3QgZW1iZWRFbGVtZW50ID0gZW1iZWRIZWxwZXIucGFyc2VFbGVtZW50Rm9yRW1iZWQoZWxlbWVudClcbiAgICAgIGlmIChlbWJlZEVsZW1lbnQpIHtcbiAgICAgICAgY29uc29sZS5sb2coXCJpc0VtYmVkZGFibGVcIilcbiAgICAgICAgcmV0dXJuIGVtYmVkRWxlbWVudFxuICAgICAgfVxuICAgIH1cblxuICAgIHJldHVybiBlbGVtZW50IGFzIEJlYW1IVE1MRWxlbWVudFxuICB9XG5cbiAgLyoqXG4gICAqIERldGVybWluZSB3aGV0aGVyIG9yIG5vdCBhbiBlbGVtZW50IGlzIHZpc2libGUgYmFzZWQgb24gaXQncyBzdHlsZVxuICAgKiBhbmQgYm91bmRpbmcgYm94IGlmIG5lY2Vzc2FyeVxuICAgKlxuICAgKiBAcGFyYW0gZWxlbWVudDoge0JlYW1FbGVtZW50fVxuICAgKiBAcGFyYW0gd2luOiB7QmVhbVdpbmRvd31cbiAgICogQHJldHVybiBJZiB0aGUgZWxlbWVudCBpcyBjb25zaWRlcmVkIHZpc2libGVcbiAgICovXG4gIC8vIGlzIHNsb3csIHByb3BlcnR5dmFsdWUgYW5kIGJvdW5kaW5ncmVjdFxuICBzdGF0aWMgaXNWaXNpYmxlKGVsZW1lbnQ6IEJlYW1FbGVtZW50LCB3aW46IEJlYW1XaW5kb3c8YW55Pik6IGJvb2xlYW4ge1xuICAgIGxldCB2aXNpYmxlID0gZmFsc2VcblxuICAgIGlmIChlbGVtZW50KSB7XG4gICAgICB2aXNpYmxlID0gdHJ1ZVxuICAgICAgLy8gV2Ugc3RhcnQgYnkgZ2V0dGluZyB0aGUgZWxlbWVudCdzIGNvbXB1dGVkIHN0eWxlIHRvIGNoZWNrIGZvciBhbnkgc21va2luZyBndW5zXG4gICAgICBjb25zdCBzdHlsZSA9IHdpbi5nZXRDb21wdXRlZFN0eWxlPy4oZWxlbWVudClcbiAgICAgIGlmIChzdHlsZSkge1xuICAgICAgICB2aXNpYmxlID0gIShcbiAgICAgICAgICAgIHN0eWxlLmdldFByb3BlcnR5VmFsdWUoXCJkaXNwbGF5XCIpID09PSBcIm5vbmVcIlxuICAgICAgICAgICAgLy8gTWF5YmUgaGlkZGVuIHNob3VsZG4ndCBiZSBmaWx0ZXJlZCBvdXQgc2VlIHRoZSBvcGFjaXR5IGNvbW1lbnRcbiAgICAgICAgICAgIHx8IFtcImhpZGRlblwiLCBcImNvbGxhcHNlXCJdLmluY2x1ZGVzKHN0eWxlLmdldFByb3BlcnR5VmFsdWUoXCJ2aXNpYmlsaXR5XCIpKVxuICAgICAgICAgICAgLy8gVGhlIGZvbGxvd2luZyBoZXVyaXN0aWMgaXNuJ3QgZW5vdWdoOiB0d2l0dGVyIHVzZXMgdHJhbnNwYXJlbnQgaW5wdXRzIG9uIHRvcCBvZiB0aGVpciBjdXN0b20gVUlcbiAgICAgICAgICAgIC8vIChzZWUgdGhlbWUgc2VsZWN0b3IgaW4gZGlzcGxheSBzZXR0aW5ncyBmb3IgYW4gZXhhbXBsZSlcbiAgICAgICAgICAgIC8vIHx8IHN0eWxlLm9wYWNpdHkgPT09ICcwJ1xuICAgICAgICAgICAgfHwgKHN0eWxlLmdldFByb3BlcnR5VmFsdWUoXCJ3aWR0aFwiKSA9PT0gXCIxcHhcIiAmJiBzdHlsZS5nZXRQcm9wZXJ0eVZhbHVlKFwiaGVpZ2h0XCIpID09PSBcIjFweFwiKVxuICAgICAgICAgICAgfHwgW1wiMHB4XCIsIFwiMFwiXS5pbmNsdWRlcyhzdHlsZS5nZXRQcm9wZXJ0eVZhbHVlKFwid2lkdGhcIikpXG4gICAgICAgICAgICB8fCBbXCIwcHhcIiwgXCIwXCJdLmluY2x1ZGVzKHN0eWxlLmdldFByb3BlcnR5VmFsdWUoXCJoZWlnaHRcIikpXG4gICAgICAgICAgICAvLyBtYW55IGNsaXBQYXRoIHZhbHVlcyBjb3VsZCBjYXVzZSB0aGUgZWxlbWVudCB0byBub3QgYmUgdmlzaWJsZSwgYnV0IGZvciBub3cgd2Ugb25seSBkZWFsIHdpdGggc2luZ2xlICUgdmFsdWVzXG4gICAgICAgICAgICB8fCAoXG4gICAgICAgICAgICAgICAgc3R5bGUuZ2V0UHJvcGVydHlWYWx1ZShcInBvc2l0aW9uXCIpID09PSBcImFic29sdXRlXCJcbiAgICAgICAgICAgICAgICAmJiBzdHlsZS5nZXRQcm9wZXJ0eVZhbHVlKFwiY2xpcFwiKS5tYXRjaCgvcmVjdFxcKCgwKHB4KT9bLCBdKyl7M30wcHhcXCkvKVxuICAgICAgICAgICAgKVxuICAgICAgICAgICAgfHwgc3R5bGUuZ2V0UHJvcGVydHlWYWx1ZShcImNsaXAtcGF0aFwiKS5tYXRjaCgvaW5zZXRcXCgoWzUtOV1cXGR8MTAwKSVcXCkvKVxuICAgICAgICApXG4gICAgICB9XG5cbiAgICAgIC8vIFN0aWxsIHZpc2libGU/IFVzZSBib3VuZGluZ0NsaWVudFJlY3QgYXMgYSBmaW5hbCBjaGVjaywgaXQncyBleHBlbnNpdmVcbiAgICAgIC8vIHNvIHdlIHNob3VsZCBzdHJpdmUgbm8gdG8gY2FsbCBpdCBpZiBpdCdzIHVubmVjZXNzYXJ5XG4gICAgICBpZiAodmlzaWJsZSkge1xuICAgICAgICBjb25zdCByZWN0OiBCZWFtUmVjdCA9IGVsZW1lbnQuZ2V0Qm91bmRpbmdDbGllbnRSZWN0KClcbiAgICAgICAgdmlzaWJsZSA9IChyZWN0LndpZHRoID4gMCAmJiByZWN0LmhlaWdodCA+IDApXG4gICAgICB9XG4gICAgfVxuICAgIHJldHVybiB2aXNpYmxlXG4gIH1cblxuICAvKipcbiAgICogUmV0dXJucyB3aGV0aGVyIGFuIGVsZW1lbnQgaXMgZWl0aGVyIGEgdmlkZW8gb3IgYW4gYXVkaW8gZWxlbWVudFxuICAgKlxuICAgKiBAcGFyYW0gZWxlbWVudFxuICAgKi9cbiAgc3RhdGljIGlzTWVkaWEoZWxlbWVudDogQmVhbUVsZW1lbnQpOiBib29sZWFuIHtcbiAgICByZXR1cm4gIChcbiAgICAgIFtcInZpZGVvXCIsIFwiYXVkaW9cIl0uaW5jbHVkZXMoZWxlbWVudC50YWdOYW1lLnRvTG93ZXJDYXNlKCkpIHx8IFxuICAgICAgQm9vbGVhbihlbGVtZW50LnF1ZXJ5U2VsZWN0b3JBbGwoXCJ2aWRlbywgYXVkaW9cIikubGVuZ3RoKVxuICAgIClcbiAgfVxuXG4gIC8qKlxuICAgKiBDaGVjayB3aGV0aGVyIGFuIGVsZW1lbnQgaXMgYW4gaW1hZ2UsIG9yIGhhcyBhIGJhY2tncm91bmQtaW1hZ2UgdXJsXG4gICAqIHRoZSBiYWNrZ3JvdW5kIGltYWdlIGNhbiBiZSBhIGRhdGE6dXJpLiBPciBoYXMgYW55IGNoaWxkIHRoYXQgaXMgYSBpbWcgb3Igc3ZnLlxuICAgKlxuICAgKiBAcGFyYW0gZWxlbWVudFxuICAgKiBAcGFyYW0gd2luXG4gICAqIEByZXR1cm4gSWYgdGhlIGVsZW1lbnQgaXMgY29uc2lkZXJlZCB2aXNpYmxlXG4gICAqL1xuICAgc3RhdGljIGlzSW1hZ2VPckNvbnRhaW5zSW1hZ2VDaGlsZChlbGVtZW50OiBCZWFtRWxlbWVudCwgd2luOiBCZWFtV2luZG93KTogYm9vbGVhbiB7XG4gICAgY29uc3QgbWF0Y2hlciA9IChlbGVtZW50OiBCZWFtRWxlbWVudCkgPT4gKFxuICAgICAgW1wiaW1nXCIsIFwic3ZnXCJdLmluY2x1ZGVzKGVsZW1lbnQudGFnTmFtZS50b0xvd2VyQ2FzZSgpKVxuICAgICAgfHwgQm9vbGVhbihlbGVtZW50LnF1ZXJ5U2VsZWN0b3JBbGwoXCJpbWcsIHN2Z1wiKS5sZW5ndGgpXG4gICAgKVxuICAgIHJldHVybiBCZWFtRWxlbWVudEhlbHBlci5pc0ltYWdlKGVsZW1lbnQsIHdpbiwgbWF0Y2hlcilcbiAgfVxuXG4gIHN0YXRpYyBpbWFnZUVsZW1lbnRNYXRjaGVyID0gKGVsZW1lbnQ6IEJlYW1FbGVtZW50KSA9PiBbXCJpbWdcIiwgXCJzdmdcIl0uaW5jbHVkZXMoZWxlbWVudC50YWdOYW1lLnRvTG93ZXJDYXNlKCkpXG4gIC8qKlxuICAgKiBDaGVjayB3aGV0aGVyIGFuIGVsZW1lbnQgaXMgYW4gaW1hZ2UsIG9yIGhhcyBhIGJhY2tncm91bmQtaW1hZ2UgdXJsXG4gICAqIHRoZSBiYWNrZ3JvdW5kIGltYWdlIGNhbiBiZSBhIGRhdGE6dXJpXG4gICAqXG4gICAqIEBwYXJhbSBlbGVtZW50XG4gICAqIEBwYXJhbSB3aW5cbiAgICogQHJldHVybiBJZiB0aGUgZWxlbWVudCBpcyBjb25zaWRlcmVkIHZpc2libGVcbiAgICovXG4gICBzdGF0aWMgaXNJbWFnZShlbGVtZW50OiBCZWFtRWxlbWVudCwgd2luOiBCZWFtV2luZG93LCBtYXRjaGVyID0gQmVhbUVsZW1lbnRIZWxwZXIuaW1hZ2VFbGVtZW50TWF0Y2hlcik6IGJvb2xlYW4ge1xuICAgICAvLyBjdXJyZW50U3JjIHZzIHNyY1xuICAgICBpZiAobWF0Y2hlcihlbGVtZW50KSkge1xuICAgICAgIHJldHVybiB0cnVlXG4gICAgIH1cbiAgICAgY29uc3Qgc3R5bGUgPSB3aW4uZ2V0Q29tcHV0ZWRTdHlsZT8uKGVsZW1lbnQpXG4gICAgIGNvbnN0IG1hdGNoID0gc3R5bGU/LmJhY2tncm91bmRJbWFnZS5tYXRjaCgvdXJsXFwoKFteKV0rKS8pXG4gICAgIHJldHVybiAhIW1hdGNoXG4gICB9XG4gXG5cbiAgLyoqXG4gICAqIFJldHVybnMgd2hldGhlciBhbiBlbGVtZW50IGlzIGFuIGltYWdlIGNvbnRhaW5lciwgd2hpY2ggbWVhbnMgaXQgY2FuIGJlIGFuIGltYWdlXG4gICAqIGl0c2VsZiBvciByZWN1cnNpdmVseSBjb250YWluIG9ubHkgaW1hZ2UgY29udGFpbmVyc1xuICAgKlxuICAgKiBAcGFyYW0gZWxlbWVudFxuICAgKiBAcGFyYW0gd2luXG4gICAqL1xuICBzdGF0aWMgaXNJbWFnZUNvbnRhaW5lcihlbGVtZW50OiBCZWFtRWxlbWVudCwgd2luOiBCZWFtV2luZG93KTogYm9vbGVhbiB7XG4gICAgaWYgKEJlYW1FbGVtZW50SGVscGVyLmlzSW1hZ2UoZWxlbWVudCwgd2luKSkge1xuICAgICAgcmV0dXJuIHRydWVcbiAgICB9XG4gICAgaWYgKGVsZW1lbnQuY2hpbGRyZW4ubGVuZ3RoID4gMCkge1xuICAgICAgcmV0dXJuIFsuLi5lbGVtZW50LmNoaWxkcmVuXS5ldmVyeShcbiAgICAgICAgICBjaGlsZCA9PiBCZWFtRWxlbWVudEhlbHBlci5pc0ltYWdlQ29udGFpbmVyKGNoaWxkLCB3aW4pXG4gICAgICApXG4gICAgfVxuICAgIHJldHVybiBmYWxzZVxuICB9XG5cbiAgLyoqXG4gICAqIFJldHVybnMgdGhlIHJvb3Qgc3ZnIGVsZW1lbnQgZm9yIHRoZSBnaXZlbiBlbGVtZW50IGlmIGFueVxuICAgKiBAcGFyYW0gZWxlbWVudFxuICAgKi9cbiAgc3RhdGljIGdldFN2Z1Jvb3QoZWxlbWVudDogQmVhbUVsZW1lbnQpOiBCZWFtRWxlbWVudCB7XG4gICAgaWYgKFtcImJvZHlcIiwgXCJodG1sXCJdLmluY2x1ZGVzKGVsZW1lbnQudGFnTmFtZS50b0xvd2VyQ2FzZSgpKSkge1xuICAgICAgcmV0dXJuXG4gICAgfVxuICAgIGlmIChlbGVtZW50LnRhZ05hbWUudG9Mb3dlckNhc2UoKSA9PT0gXCJzdmdcIikge1xuICAgICAgcmV0dXJuIGVsZW1lbnRcbiAgICB9XG4gICAgaWYgKGVsZW1lbnQucGFyZW50RWxlbWVudCkge1xuICAgICAgcmV0dXJuIEJlYW1FbGVtZW50SGVscGVyLmdldFN2Z1Jvb3QoZWxlbWVudC5wYXJlbnRFbGVtZW50KVxuICAgIH1cbiAgfVxuXG4gIC8qKlxuICAgKiBSZXR1cm5zIHRoZSBmaXJzdCBwb3NpdGlvbmVkIGVsZW1lbnQgb3V0IG9mIHRoZSBlbGVtZW50IGl0c2VsZiBhbmQgaXRzIGFuY2VzdG9yc1xuICAgKlxuICAgKiBAcGFyYW0gZWxlbWVudFxuICAgKiBAcGFyYW0gd2luXG4gICAqL1xuICBzdGF0aWMgZ2V0UG9zaXRpb25lZEVsZW1lbnQoZWxlbWVudDogQmVhbUVsZW1lbnQsIHdpbjogQmVhbVdpbmRvdyk6IEJlYW1FbGVtZW50IHtcbiAgICAvLyBJZ25vcmUgYm9keVxuICAgIGlmICghZWxlbWVudCB8fCBlbGVtZW50ID09PSB3aW4uZG9jdW1lbnQuYm9keSkge1xuICAgICAgcmV0dXJuXG4gICAgfVxuICAgIGNvbnN0IHN0eWxlID0gd2luLmdldENvbXB1dGVkU3R5bGU/LihlbGVtZW50KVxuXG4gICAgaWYgKGVsZW1lbnQucGFyZW50RWxlbWVudCAmJiBzdHlsZT8ucG9zaXRpb24gPT09IFwic3RhdGljXCIpIHtcbiAgICAgIHJldHVybiBCZWFtRWxlbWVudEhlbHBlci5nZXRQb3NpdGlvbmVkRWxlbWVudChlbGVtZW50LnBhcmVudEVsZW1lbnQsIHdpbilcbiAgICB9XG4gICAgaWYgKHN0eWxlPy5wb3NpdGlvbiAhPT0gXCJzdGF0aWNcIikge1xuICAgICAgcmV0dXJuIGVsZW1lbnRcbiAgICB9XG4gIH1cblxuICAvKipcbiAgICogUmV0dXJuIHRoZSBmaXJzdCBvdmVyZmxvdyBlc2NhcGluZyBlbGVtZW50LiBTaW5jZSBjc3Mgb3ZlcmZsb3cgY2FuIGJlIGVzY2FwZWQgYnkgcG9zaXRpb25pbmdcbiAgICogYW4gZWxlbWVudCByZWxhdGl2ZSB0byB0aGUgdmlld3BvcnQsIGVpdGhlciBieSB1c2luZyBgZml4ZWRgLCBvciBgYWJzb2x1dGVgIGluIHRoZSBjYXNlXG4gICAqIHRoZXJlJ3Mgbm8gb3RoZXIgcG9zaXRpb25pbmcgY29udGV4dFxuICAgKlxuICAgKiBAcGFyYW0gZWxlbWVudFxuICAgKiBAcGFyYW0gY2xpcHBpbmdDb250YWluZXJcbiAgICogQHBhcmFtIHdpblxuICAgKi9cbiAgc3RhdGljIGdldE92ZXJmbG93RXNjYXBpbmdFbGVtZW50KGVsZW1lbnQ6IEJlYW1FbGVtZW50LCBjbGlwcGluZ0NvbnRhaW5lcjogQmVhbUVsZW1lbnQsIHdpbjogQmVhbVdpbmRvdyk6IEJlYW1FbGVtZW50IHtcbiAgICAvLyBJZ25vcmUgYm9keVxuICAgIGlmICghZWxlbWVudCB8fCBlbGVtZW50ID09PSB3aW4uZG9jdW1lbnQuYm9keSkge1xuICAgICAgcmV0dXJuXG4gICAgfVxuICAgIGNvbnN0IHN0eWxlID0gd2luLmdldENvbXB1dGVkU3R5bGU/LihlbGVtZW50KVxuICAgIGlmIChzdHlsZSkge1xuICAgICAgc3dpdGNoIChzdHlsZS5wb3NpdGlvbikge1xuICAgICAgICBjYXNlIFwiYWJzb2x1dGVcIjoge1xuICAgICAgICAgIC8vIElmIGFic29sdXRlLCB3ZSBuZWVkIHRvIG1ha2Ugc3VyZSBpdCdzIG5vdCB3aXRoaW4gYSBwb3NpdGlvbmVkIGVsZW1lbnQgYWxyZWFkeVxuICAgICAgICAgIGNvbnN0IHBvc2l0aW9uZWRBbmNlc3RvciA9IEJlYW1FbGVtZW50SGVscGVyLmdldFBvc2l0aW9uZWRFbGVtZW50KGVsZW1lbnQucGFyZW50RWxlbWVudCwgd2luKVxuICAgICAgICAgIGlmIChwb3NpdGlvbmVkQW5jZXN0b3IgJiYgcG9zaXRpb25lZEFuY2VzdG9yLmNvbnRhaW5zKGNsaXBwaW5nQ29udGFpbmVyKSkge1xuICAgICAgICAgICAgcmV0dXJuIGVsZW1lbnRcbiAgICAgICAgICB9XG4gICAgICAgICAgcmV0dXJuIGVsZW1lbnRcbiAgICAgICAgfVxuICAgICAgICBjYXNlIFwiZml4ZWRcIjpcbiAgICAgICAgICAvLyBGaXhlZCBlbGVtZW50cyBhbHdheXMgZXNjYXBlIG92ZXJmbG93IGNsaXBwaW5nXG4gICAgICAgICAgcmV0dXJuIGVsZW1lbnRcbiAgICAgICAgZGVmYXVsdDpcbiAgICAgICAgICByZXR1cm4gQmVhbUVsZW1lbnRIZWxwZXIuZ2V0T3ZlcmZsb3dFc2NhcGluZ0VsZW1lbnQoXG4gICAgICAgICAgICAgIGVsZW1lbnQucGFyZW50RWxlbWVudCwgY2xpcHBpbmdDb250YWluZXIsIHdpblxuICAgICAgICAgIClcbiAgICAgIH1cbiAgICB9XG4gIH1cblxuICAvKipcbiAgICogUmVjdXJzaXZlbHkgbG9vayBmb3IgdGhlIGZpcnN0IGFuY2VzdG9yIGVsZW1lbnQgd2l0aCBhbiBgb3ZlcmZsb3dgLCBgY2xpcGAsIG9yIGBjbGlwLXBhdGhcbiAgICogY3NzIHByb3BlcnR5IHRyaWdnZXJpbmcgY2xpcHBpbmcgb24gdGhlIGVsZW1lbnRcbiAgICpcbiAgICogQHBhcmFtIGVsZW1lbnRcbiAgICogQHBhcmFtIHdpblxuICAgKi9cbiAgc3RhdGljIGdldENsaXBwaW5nRWxlbWVudChlbGVtZW50OiBCZWFtRWxlbWVudCwgd2luOiBCZWFtV2luZG93KTogQmVhbUVsZW1lbnQge1xuICAgIC8vIElnbm9yZSBib2R5XG4gICAgaWYgKGVsZW1lbnQgPT09IHdpbi5kb2N1bWVudC5ib2R5KSB7XG4gICAgICByZXR1cm5cbiAgICB9XG4gICAgY29uc3Qgc3R5bGUgPSB3aW4uZ2V0Q29tcHV0ZWRTdHlsZT8uKGVsZW1lbnQpXG4gICAgaWYgKHN0eWxlKSB7XG4gICAgICBpZiAoXG4gICAgICAgICAgc3R5bGUuZ2V0UHJvcGVydHlWYWx1ZShcIm92ZXJmbG93XCIpID09PSBcInZpc2libGVcIlxuICAgICAgICAgICYmIHN0eWxlLmdldFByb3BlcnR5VmFsdWUoXCJvdmVyZmxvdy14XCIpID09PSBcInZpc2libGVcIlxuICAgICAgICAgICYmIHN0eWxlLmdldFByb3BlcnR5VmFsdWUoXCJvdmVyZmxvdy15XCIpID09PSBcInZpc2libGVcIlxuICAgICAgICAgICYmIHN0eWxlLmdldFByb3BlcnR5VmFsdWUoXCJjbGlwXCIpID09PSBcImF1dG9cIlxuICAgICAgICAgICYmIHN0eWxlLmdldFByb3BlcnR5VmFsdWUoXCJjbGlwLXBhdGhcIikgPT09IFwibm9uZVwiXG4gICAgICApIHtcbiAgICAgICAgaWYgKGVsZW1lbnQucGFyZW50RWxlbWVudCkge1xuICAgICAgICAgIHJldHVybiBCZWFtRWxlbWVudEhlbHBlci5nZXRDbGlwcGluZ0VsZW1lbnQoZWxlbWVudC5wYXJlbnRFbGVtZW50LCB3aW4pXG4gICAgICAgIH1cbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIHJldHVybiBlbGVtZW50XG4gICAgICB9XG4gICAgfSBlbHNlIHtcbiAgICAgIGlmIChlbGVtZW50LnBhcmVudEVsZW1lbnQpIHtcbiAgICAgICAgcmV0dXJuIEJlYW1FbGVtZW50SGVscGVyLmdldENsaXBwaW5nRWxlbWVudChlbGVtZW50LnBhcmVudEVsZW1lbnQsIHdpbilcbiAgICAgIH1cbiAgICB9XG4gICAgcmV0dXJuXG4gIH1cblxuICAvKipcbiAgICogSW5zcGVjdCB0aGUgZWxlbWVudCBpdHNlbGYgYW5kIGl0cyBhbmNlc3RvcnMgYW5kIHJldHVybiB0aGUgY29sbGVjdGlvbiBvZiBlbGVtZW50c1xuICAgKiB3aXRoIGNsaXBwaW5nIGFjdGl2ZSBkdWUgdG8gdGhlIHByZXNlbmNlIG9mIGBvdmVyZmxvd2AsIGBjbGlwYCBvciBgY2xpcC1wYXRoYCBjc3MgcHJvcGVydGllc1xuICAgKlxuICAgKiBAcGFyYW0gZWxlbWVudFxuICAgKiBAcGFyYW0gd2luXG4gICAqL1xuICBzdGF0aWMgZ2V0Q2xpcHBpbmdFbGVtZW50cyhlbGVtZW50OiBCZWFtRWxlbWVudCwgd2luOiBCZWFtV2luZG93PGFueT4pOiBCZWFtRWxlbWVudFtdIHtcbiAgICBjb25zdCBjbGlwcGluZ0VsZW1lbnQgPSBCZWFtRWxlbWVudEhlbHBlci5nZXRDbGlwcGluZ0VsZW1lbnQoZWxlbWVudCwgd2luKVxuICAgIGlmICghY2xpcHBpbmdFbGVtZW50KSB7XG4gICAgICByZXR1cm4gW11cbiAgICB9XG4gICAgaWYgKGNsaXBwaW5nRWxlbWVudC5wYXJlbnRFbGVtZW50ICYmIGNsaXBwaW5nRWxlbWVudC5wYXJlbnRFbGVtZW50ICE9PSB3aW4uZG9jdW1lbnQuYm9keSkge1xuICAgICAgcmV0dXJuIFtcbiAgICAgICAgY2xpcHBpbmdFbGVtZW50LFxuICAgICAgICAuLi5CZWFtRWxlbWVudEhlbHBlci5nZXRDbGlwcGluZ0VsZW1lbnRzKGNsaXBwaW5nRWxlbWVudC5wYXJlbnRFbGVtZW50LCB3aW4pXG4gICAgICBdXG4gICAgfVxuICAgIHJldHVybiBbY2xpcHBpbmdFbGVtZW50XVxuICB9XG5cbiAgLyoqXG4gICAqIENvbXB1dGUgaW50ZXJzZWN0aW9uIG9mIGFsbCB0aGUgY2xpcHBpbmcgYXJlYXMgb2YgdGhlIGdpdmVuIGVsZW1lbnRzIGNvbGxlY3Rpb25cbiAgICogdGhlIHJlc3VsdGluZyBhcmVhIG1pZ2h0IGV4dGVuZCBpbmZpbml0ZWx5IGluIG9uZSBvZiBpdHMgZGltZW5zaW9uc1xuICAgKlxuICAgKiBAcGFyYW0gZWxlbWVudHNcbiAgICogQHBhcmFtIHdpblxuICAgKi9cbiAgc3RhdGljIGdldENsaXBwaW5nQXJlYShlbGVtZW50czogQmVhbUVsZW1lbnRbXSwgd2luOiBCZWFtV2luZG93PGFueT4pOiBCZWFtUmVjdCB7XG4gICAgY29uc3QgYXJlYXM6IEJlYW1SZWN0W10gPSBlbGVtZW50cy5tYXAoZWwgPT4ge1xuICAgICAgY29uc3Qgc3R5bGUgPSB3aW4uZ2V0Q29tcHV0ZWRTdHlsZT8uKGVsKVxuICAgICAgaWYgKHN0eWxlKSB7XG4gICAgICAgIGNvbnN0IG92ZXJmbG93WCA9IHN0eWxlLmdldFByb3BlcnR5VmFsdWUoXCJvdmVyZmxvdy14XCIpICE9PSBcInZpc2libGVcIlxuICAgICAgICBjb25zdCBvdmVyZmxvd1kgPSBzdHlsZS5nZXRQcm9wZXJ0eVZhbHVlKFwib3ZlcmZsb3cteVwiKSAhPT0gXCJ2aXNpYmxlXCJcbiAgICAgICAgY29uc3QgYm91bmRzID0gZWwuZ2V0Qm91bmRpbmdDbGllbnRSZWN0KClcbiAgICAgICAgaWYgKG92ZXJmbG93WCAmJiAhb3ZlcmZsb3dZKSB7XG4gICAgICAgICAgcmV0dXJuIHt4OiBib3VuZHMueCwgd2lkdGg6IGJvdW5kcy53aWR0aCwgeTogLUluZmluaXR5LCBoZWlnaHQ6IEluZmluaXR5fVxuICAgICAgICB9XG4gICAgICAgIGlmIChvdmVyZmxvd1kgJiYgIW92ZXJmbG93WCkge1xuICAgICAgICAgIHJldHVybiB7eTogYm91bmRzLnksIGhlaWdodDogYm91bmRzLmhlaWdodCwgeDogLUluZmluaXR5LCB3aWR0aDogSW5maW5pdHl9XG4gICAgICAgIH1cbiAgICAgICAgcmV0dXJuIGJvdW5kc1xuICAgICAgfVxuICAgIH0pXG5cbiAgICByZXR1cm4gYXJlYXMucmVkdWNlKFxuICAgICAgICAoY2xpcHBpbmdBcmVhLCBhcmVhKSA9PiAoXG4gICAgICAgICAgICBjbGlwcGluZ0FyZWFcbiAgICAgICAgICAgICAgICA/IEJlYW1SZWN0SGVscGVyLmludGVyc2VjdGlvbihjbGlwcGluZ0FyZWEsIGFyZWEpXG4gICAgICAgICAgICAgICAgOiBhcmVhXG4gICAgICAgICksIG51bGxcbiAgICApXG4gIH1cblxuICAvKipcbiAgICogUmV0dXJucyB0aGUgY2xpcHBpbmcgY29udGFpbmVycyB3aGljaCB0aGUgZWxlbWVudCBkb2Vzbid0IGNvbnRhaW5cbiAgICogQHBhcmFtIGVsZW1lbnRcbiAgICogQHBhcmFtIHdpblxuICAgKi9cbiAgc3RhdGljIGdldENsaXBwaW5nQ29udGFpbmVycyhlbGVtZW50OiBCZWFtRWxlbWVudCwgd2luOiBCZWFtV2luZG93KTogQmVhbUVsZW1lbnRbXSB7XG4gICAgcmV0dXJuIEJlYW1FbGVtZW50SGVscGVyXG4gICAgICAgIC5nZXRDbGlwcGluZ0VsZW1lbnRzKGVsZW1lbnQsIHdpbilcbiAgICAgICAgLmZpbHRlcihjb250YWluZXIgPT4ge1xuICAgICAgICAgIGNvbnN0IGVzY2FwaW5nRWxlbWVudCA9IEJlYW1FbGVtZW50SGVscGVyLmdldE92ZXJmbG93RXNjYXBpbmdFbGVtZW50KGVsZW1lbnQsIGNvbnRhaW5lciwgd2luKVxuICAgICAgICAgIHJldHVybiAhZXNjYXBpbmdFbGVtZW50IHx8IGVzY2FwaW5nRWxlbWVudC5jb250YWlucyhjb250YWluZXIpXG4gICAgICAgIH0pXG4gIH1cbiAgLyoqXG4gICAqIENoZWNrcyBpZiB0YXJnZXQgaXMgMTIwJSB0YWxsZXIgb3IgMTEwJSB3aWRlciB0aGFuIHdpbmRvdyBmcmFtZS5cbiAgICpcbiAgICogQHN0YXRpY1xuICAgKiBAcGFyYW0ge0RPTVJlY3R9IGJvdW5kcyBlbGVtZW50IGJvdW5kcyB0byBjaGVja1xuICAgKiBAcGFyYW0ge0JlYW1XaW5kb3d9IHdpbiBcbiAgICogQHJldHVybiB7Kn0gIHtib29sZWFufSB0cnVlIGlmIGVpdGhlciB3aWR0aCBvciBoZWlnaHQgaXMgbGFyZ2VcbiAgICogQG1lbWJlcm9mIFBvaW50QW5kU2hvb3RIZWxwZXJcbiAgICovXG4gICBzdGF0aWMgaXNMYXJnZXJUaGFuV2luZG93KGJvdW5kczogRE9NUmVjdCwgd2luOiBCZWFtV2luZG93KTogYm9vbGVhbiB7ICBcbiAgICBjb25zdCB3aW5kb3dIZWlnaHQgPSB3aW4uaW5uZXJIZWlnaHRcbiAgICBjb25zdCB5UGVyY2VudCA9ICgxMDAgLyB3aW5kb3dIZWlnaHQpICogYm91bmRzLmhlaWdodFxuICAgIGNvbnN0IHlJc0xhcmdlID0geVBlcmNlbnQgPiAxMTBcbiAgICAvLyBJZiBwb3NzaWJsZSByZXR1cm4gZWFybHkgdG8gc2tpcCB0aGUgc2Vjb25kIHdpbi5pbm50ZXJXaWR0aCBjYWxsXG4gICAgaWYgKHlJc0xhcmdlKSB7XG4gICAgICByZXR1cm4geUlzTGFyZ2VcbiAgICB9XG4gICAgXG4gICAgY29uc3Qgd2luZG93V2lkdGggPSB3aW4uaW5uZXJXaWR0aFxuICAgIGNvbnN0IHhQZXJjZW50ID0gKDEwMCAvIHdpbmRvd1dpZHRoKSAqIGJvdW5kcy53aWR0aFxuICAgIGNvbnN0IHhJc0xhcmdlID0geFBlcmNlbnQgPiAxMTBcbiAgICByZXR1cm4geElzTGFyZ2VcbiAgfVxufVxuIiwiaW1wb3J0IHtcbiAgQmVhbUVsZW1lbnQsXG4gIEJlYW1IVE1MRWxlbWVudCxcbiAgQmVhbVdpbmRvdyxcbiAgTWVzc2FnZUhhbmRsZXJzXG59IGZyb20gXCJAYmVhbS9uYXRpdmUtYmVhbXR5cGVzXCJcbmltcG9ydCB7ZGVxdWFsIGFzIGlzRGVlcEVxdWFsfSBmcm9tIFwiZGVxdWFsXCJcblxuZXhwb3J0IGNsYXNzIEJlYW1FbWJlZEhlbHBlciB7XG4gIGVtYmVkUGF0dGVybiA9IFwiX19FTUJFRFBBVFRFUk5fX1wiXG4gIGVtYmVkUmVnZXg6IFJlZ0V4cFxuICAvLyBVc2VkIHdoZW4gdGhlIGVtYmVkIGlmcmFtZSBuYXZpZ2F0ZXMgYWZ0ZXIgbG9hZGluZyB0aGUgZmlyc3QgdXJsXG4gIGZpcnN0TG9jYXRpb25Mb2FkZWQ/OiBMb2NhdGlvblxuICB3aW46IEJlYW1XaW5kb3c8TWVzc2FnZUhhbmRsZXJzPlxuXG4gIGNvbnN0cnVjdG9yKHdpbjogQmVhbVdpbmRvdykge1xuICAgIHRoaXMud2luID0gd2luXG4gICAgdGhpcy5lbWJlZFJlZ2V4ID0gbmV3IFJlZ0V4cCh0aGlzLmVtYmVkUGF0dGVybiwgXCJpXCIpXG4gICAgdGhpcy5maXJzdExvY2F0aW9uTG9hZGVkID0gdGhpcy53aW4ubG9jYXRpb25cbiAgfVxuXG4gIC8qKlxuICAgKiBSZXR1cm5zIHRydWUgaWYgZWxlbWVudCBpcyBFbWJlZC5cbiAgICpcbiAgICogQHBhcmFtIHtCZWFtRWxlbWVudH0gZWxlbWVudFxuICAgKiBAcGFyYW0ge0JlYW1XaW5kb3d9IHdpblxuICAgKiBAcmV0dXJuIHsqfSAge2Jvb2xlYW59XG4gICAqIEBtZW1iZXJvZiBCZWFtRW1iZWRIZWxwZXJcbiAgICovXG4gICBpc0VtYmVkZGFibGVFbGVtZW50KGVsZW1lbnQ6IGFueSk6IGJvb2xlYW4ge1xuICAgICBjb25zdCBpc0luc2lkZUlmcmFtZSA9IHRoaXMuaXNPbkZ1bGxFbWJlZGRhYmxlUGFnZSgpXG4gICAgIC8vIENoZWNrIGlmIGN1cnJlbnQgd2luZG93IGxvY2F0aW9uIGlzIG1hdGNoaW5nIGVtYmVkIHVybCBhbmQgaXMgaW5zaWRlIGFuIGlmcmFtZSBjb250ZXh0XG4gICAgIGlmIChpc0luc2lkZUlmcmFtZSkge1xuICAgICAgIHJldHVybiBpc0luc2lkZUlmcmFtZVxuICAgICAgfVxuICAgICAgXG4gICAgLy8gY2hlY2sgdGhlIGVsZW1lbnQgaWYgaXQncyBlbWJlZGRhYmxlXG4gICAgc3dpdGNoICh0aGlzLndpbi5sb2NhdGlvbi5ob3N0bmFtZSkge1xuICAgICAgY2FzZSBcInR3aXR0ZXIuY29tXCI6XG4gICAgICAgIHJldHVybiB0aGlzLmlzVHdlZXQoZWxlbWVudClcbiAgICAgICAgYnJlYWtcbiAgICAgIGNhc2UgXCJ3d3cueW91dHViZS5jb21cIjpcbiAgICAgICAgcmV0dXJuIChcbiAgICAgICAgICB0aGlzLmlzWW91VHViZVRodW1ibmFpbChlbGVtZW50KSB8fFxuICAgICAgICAgIHRoaXMuaXNFbWJlZGRhYmxlSWZyYW1lKGVsZW1lbnQpIHx8XG4gICAgICAgICAgdGhpcy53aW4ubG9jYXRpb24ucGF0aG5hbWUuaW5jbHVkZXMoXCIvZW1iZWQvXCIpXG4gICAgICAgIClcbiAgICAgICAgYnJlYWtcbiAgICAgIGRlZmF1bHQ6XG4gICAgICAgIHJldHVybiB0aGlzLmlzRW1iZWRkYWJsZUlmcmFtZShlbGVtZW50KVxuICAgICAgICBicmVha1xuICAgIH1cbiAgfVxuXG4gIC8qKlxuICAgKiBSZXR1cm5zIHRoZSB3aW5kb3cgbG9jYXRpb24gb3IgZmlyc3QgbG9hZGVkIGxvY2F0aW9uIHRoYXQgbWF0Y2hlcyBcbiAgICogdGhlIGVtYmVkIG9yIGlmcmFtZSByZWdleFxuICAgKlxuICAgKiBAcmV0dXJuIHsqfSAgeyhzdHJpbmcgfCB1bmRlZmluZWQpfVxuICAgKiBAbWVtYmVyb2YgQmVhbUVtYmVkSGVscGVyXG4gICAqL1xuICBnZXRFbWJlZGRhYmxlV2luZG93TG9jYXRpb25MYXN0VXJsczogc3RyaW5nW11cbiAgZ2V0RW1iZWRkYWJsZVdpbmRvd0xvY2F0aW9uTGFzdFJlc3VsdDogc3RyaW5nXG4gIGdldEVtYmVkZGFibGVXaW5kb3dMb2NhdGlvbigpOiBzdHJpbmcgfCB1bmRlZmluZWQge1xuICAgIGNvbnN0IHVybHMgPSBbIHRoaXMud2luLmxvY2F0aW9uLmhyZWYsIHRoaXMuZmlyc3RMb2NhdGlvbkxvYWRlZC5ocmVmIF1cbiAgICBpZiAoaXNEZWVwRXF1YWwodXJscywgdGhpcy5nZXRFbWJlZGRhYmxlV2luZG93TG9jYXRpb25MYXN0VXJscykpIHtcbiAgICAgIHJldHVybiB0aGlzLmdldEVtYmVkZGFibGVXaW5kb3dMb2NhdGlvbkxhc3RSZXN1bHRcbiAgICB9XG4gICAgXG4gICAgY29uc3QgcmVzdWx0ID0gdXJscy5maW5kKHVybCA9PiB7XG4gICAgICByZXR1cm4gdGhpcy5lbWJlZFJlZ2V4LnRlc3QodXJsKVxuICAgIH0pXG4gICAgXG4gICAgdGhpcy5nZXRFbWJlZGRhYmxlV2luZG93TG9jYXRpb25MYXN0VXJscyA9IHVybHNcbiAgICB0aGlzLmdldEVtYmVkZGFibGVXaW5kb3dMb2NhdGlvbkxhc3RSZXN1bHQgPSByZXN1bHRcblxuICAgIHJldHVybiByZXN1bHRcbiAgfVxuXG4gIGlzT25GdWxsRW1iZWRkYWJsZVBhZ2UoKSB7XG4gICAgcmV0dXJuIChcbiAgICAgIChcbiAgICAgICAgdGhpcy51cmxNYXRjaGVzRW1iZWRQcm92aWRlcihbdGhpcy53aW4ubG9jYXRpb24uaHJlZiwgdGhpcy5maXJzdExvY2F0aW9uTG9hZGVkLmhyZWZdKVxuICAgICAgKSAmJlxuICAgICAgdGhpcy5pc0luc2lkZUlmcmFtZSgpXG4gICAgKVxuICB9XG5cbiAgaXNFbWJlZGRhYmxlSWZyYW1lKGVsZW1lbnQ6IEJlYW1FbGVtZW50KTogYm9vbGVhbiB7XG4gICAgaWYgKFtcImlmcmFtZVwiXS5pbmNsdWRlcyhlbGVtZW50LnRhZ05hbWUudG9Mb3dlckNhc2UoKSkpIHtcbiAgICAgIHJldHVybiB0aGlzLnVybE1hdGNoZXNFbWJlZFByb3ZpZGVyKFtlbGVtZW50LnNyY10pXG4gICAgfVxuICAgIHJldHVybiBmYWxzZVxuICB9XG5cbiAgdXJsTWF0Y2hlc0VtYmVkUHJvdmlkZXJMYXN0VXJsczogc3RyaW5nW11cbiAgdXJsTWF0Y2hlc0VtYmVkUHJvdmlkZXJMYXN0UmVzdWx0OiBib29sZWFuXG4gIHVybE1hdGNoZXNFbWJlZFByb3ZpZGVyKHVybHM6IHN0cmluZ1tdKTogYm9vbGVhbiB7XG4gICAgaWYgKGlzRGVlcEVxdWFsKHVybHMsIHRoaXMudXJsTWF0Y2hlc0VtYmVkUHJvdmlkZXJMYXN0VXJscykpIHtcbiAgICAgIHJldHVybiB0aGlzLnVybE1hdGNoZXNFbWJlZFByb3ZpZGVyTGFzdFJlc3VsdFxuICAgIH1cbiAgICBjb25zdCByZXN1bHQgPSB1cmxzLnNvbWUoKHVybCkgPT4ge1xuICAgICAgaWYgKCF1cmwpIHJldHVybiBmYWxzZVxuICAgICAgcmV0dXJuIHRoaXMuZW1iZWRSZWdleC50ZXN0KHVybCkgfHwgdXJsLmluY2x1ZGVzKFwieW91dHViZS5jb20vZW1iZWRcIilcbiAgICB9KVxuXG4gICAgdGhpcy51cmxNYXRjaGVzRW1iZWRQcm92aWRlckxhc3RVcmxzID0gdXJsc1xuICAgIHRoaXMudXJsTWF0Y2hlc0VtYmVkUHJvdmlkZXJMYXN0UmVzdWx0ID0gcmVzdWx0XG5cbiAgICByZXR1cm4gcmVzdWx0XG4gIH1cblxuICAvKipcbiAgICogUmV0dXJucyB0cnVlIGlmIGN1cnJlbnQgd2luZG93IGNvbnRleHQgaXMgbm90IHRoZSB0b3AgbGV2ZWwgd2luZG93IGNvbnRleHRcbiAgICpcbiAgICogQHJldHVybiB7Kn0gIHtib29sZWFufVxuICAgKiBAbWVtYmVyb2YgQmVhbUVtYmVkSGVscGVyXG4gICAqL1xuICBpc0luc2lkZUlmcmFtZSgpOiBib29sZWFuIHtcbiAgICB0cnkge1xuICAgICAgcmV0dXJuIHdpbmRvdy5zZWxmICE9PSB3aW5kb3cudG9wXG4gICAgfSBjYXRjaCAoZSkge1xuICAgICAgcmV0dXJuIHRydWVcbiAgICB9XG4gIH1cblxuICAvKipcbiAgICogUmV0dXJucyBhIHVybCB0byB0aGUgY29udGVudCB0byBiZSBpbnNlcnRlZCB0byB0aGUgam91cm5hbCBhcyBlbWJlZC5cbiAgICpcbiAgICogQHBhcmFtIHtCZWFtRWxlbWVudH0gZWxlbWVudFxuICAgKiBAcGFyYW0ge0JlYW1XaW5kb3d9IHdpblxuICAgKiBAcmV0dXJuIHsqfSAge0JlYW1IVE1MRWxlbWVudH1cbiAgICogQG1lbWJlcm9mIHRoaXNcbiAgICovXG4gIHBhcnNlRWxlbWVudEZvckVtYmVkKGVsZW1lbnQ6IEJlYW1FbGVtZW50KTogQmVhbUhUTUxFbGVtZW50IHtcbiAgICBjb25zdCB7IGhvc3RuYW1lIH0gPSB0aGlzLndpbi5sb2NhdGlvblxuXG4gICAgc3dpdGNoIChob3N0bmFtZSkge1xuICAgICAgY2FzZSBcInR3aXR0ZXIuY29tXCI6XG4gICAgICAgIC8vIHNlZSBpZiB3ZSB0YXJnZXQgdGhlIHR3ZWV0IGh0bWxcbiAgICAgICAgcmV0dXJuIHRoaXMucGFyc2VUd2l0dGVyRWxlbWVudEZvckVtYmVkKGVsZW1lbnQpXG4gICAgICAgIGJyZWFrXG4gICAgICBjYXNlIFwid3d3LnlvdXR1YmUuY29tXCI6XG4gICAgICAgIGlmICh0aGlzLndpbi5sb2NhdGlvbi5wYXRobmFtZS5pbmNsdWRlcyhcIi9lbWJlZC9cIikpIHtcbiAgICAgICAgICBjb25zdCB2aWRlb0lkID0gd2luZG93LmxvY2F0aW9uLnBhdGhuYW1lLnNwbGl0KFwiL1wiKS5wb3AoKVxuICAgICAgICAgIHJldHVybiB0aGlzLmNyZWF0ZUxpbmtFbGVtZW50KFxuICAgICAgICAgICAgYGh0dHBzOi8vd3d3LnlvdXR1YmUuY29tL3dhdGNoP3Y9JHt2aWRlb0lkfWBcbiAgICAgICAgICApXG4gICAgICAgIH1cbiAgICAgICAgcmV0dXJuIHRoaXMucGFyc2VZb3VUdWJlVGh1bWJuYWlsRm9yRW1iZWQoZWxlbWVudClcbiAgICAgICAgYnJlYWtcbiAgICAgIGRlZmF1bHQ6XG4gICAgICAgIGlmIChlbGVtZW50LnNyYyAmJiB0aGlzLnVybE1hdGNoZXNFbWJlZFByb3ZpZGVyKFtlbGVtZW50LnNyY10pKSB7XG4gICAgICAgICAgcmV0dXJuIHRoaXMuY3JlYXRlTGlua0VsZW1lbnQoZWxlbWVudC5zcmMpXG4gICAgICAgIH1cbiAgICAgICAgYnJlYWtcbiAgICB9XG4gIH1cbiAgLyoqXG4gICAqIENvbnZlcnQgZWxlbWVudCBmb3VuZCBvbiB0d2l0dGVyLmNvbSB0byBhIGFuY2hvciBlbGVtbnQgY29udGFpbmluZyB0aGUgdHdlZXQgdXJsLlxuICAgKiByZXR1cm5zIHVuZGVmaW5lZCB3aGVuIGVsZW1lbnQgaXNuJ3QgYSB0d2VldFxuICAgKlxuICAgKiBAcGFyYW0ge0JlYW1FbGVtZW50fSBlbGVtZW50XG4gICAqIEBwYXJhbSB7QmVhbVdpbmRvdzxhbnk+fSB3aW5cbiAgICogQHJldHVybiB7Kn0gIHtCZWFtSFRNTEVsZW1lbnR9XG4gICAqIEBtZW1iZXJvZiB0aGlzXG4gICAqL1xuICBwYXJzZVR3aXR0ZXJFbGVtZW50Rm9yRW1iZWQoZWxlbWVudDogQmVhbUVsZW1lbnQpOiBCZWFtSFRNTEVsZW1lbnQge1xuICAgIGlmICghdGhpcy5pc1R3ZWV0KGVsZW1lbnQpKSB7XG4gICAgICByZXR1cm5cbiAgICB9XG5cbiAgICAvLyBXZSBhcmUgbG9va2luZyBmb3IgYSB1cmwgbGlrZTogPHVzZXJuYW1lPi9zdGF0dXMvMTMxODU4NDE0OTI0NzE2ODUxM1xuICAgIGNvbnN0IGxpbmtFbGVtZW50cyA9IGVsZW1lbnQucXVlcnlTZWxlY3RvckFsbChcImFbaHJlZio9XFxcIi9zdGF0dXMvXFxcIl1cIilcbiAgICAvLyByZXR1cm4gdGhlIGhyZWYgb2YgdGhlIGZpcnN0IGVsZW1lbnQgaW4gTm9kZUxpc3RcbiAgICBjb25zdCBocmVmID0gbGlua0VsZW1lbnRzPy5bMF0uaHJlZlxuXG4gICAgaWYgKGhyZWYpIHtcbiAgICAgIHJldHVybiB0aGlzLmNyZWF0ZUxpbmtFbGVtZW50KGhyZWYpXG4gICAgfVxuXG4gICAgcmV0dXJuXG4gIH1cblxuICAvKipcbiAgICogUmV0dXJucyBpZiB0aGUgcHJvdmlkZWQgZWxlbWVudCBpcyBhIHR3ZWV0LiBTaG91bGQgb25seSBiZSBydW4gb24gdHdpdHRlci5jb21cbiAgICpcbiAgICogQHBhcmFtIHtCZWFtRWxlbWVudH0gZWxlbWVudFxuICAgKiBAcmV0dXJuIHsqfSAge2Jvb2xlYW59XG4gICAqIEBtZW1iZXJvZiB0aGlzXG4gICAqL1xuICBpc1R3ZWV0KGVsZW1lbnQ6IEJlYW1FbGVtZW50KTogYm9vbGVhbiB7XG4gICAgcmV0dXJuIGVsZW1lbnQuZ2V0QXR0cmlidXRlKFwiZGF0YS10ZXN0aWRcIikgPT0gXCJ0d2VldFwiXG4gIH1cbiAgLyoqXG4gICAqIFJldHVybnMgaWYgdGhlIHByb3ZpZGVkIGVsZW1lbnQgaXMgYSBZb3VUdWJlIFRodW1ibmFpbC4gU2hvdWxkIG9ubHkgYmUgcnVuIG9uIHlvdXR1YmUuY29tXG4gICAqXG4gICAqIEBwYXJhbSB7QmVhbUVsZW1lbnR9IGVsZW1lbnRcbiAgICogQHJldHVybiB7Kn0gIHtib29sZWFufVxuICAgKiBAbWVtYmVyb2YgdGhpc1xuICAgKi9cbiAgaXNZb3VUdWJlVGh1bWJuYWlsKGVsZW1lbnQ6IEJlYW1FbGVtZW50KTogYm9vbGVhbiB7XG4gICAgY29uc3QgaXNUaHVtYiA9IEJvb2xlYW4oZWxlbWVudD8uaHJlZj8uaW5jbHVkZXMoXCIvd2F0Y2g/dj1cIikpXG5cbiAgICBpZiAoaXNUaHVtYikge1xuICAgICAgcmV0dXJuIHRydWVcbiAgICB9XG5cbiAgICBjb25zdCBwYXJlbnRMaW5rRWxlbWVudCA9IHRoaXMuaGFzUGFyZW50T2ZUeXBlKGVsZW1lbnQsIFwiQVwiLCA1KVxuICAgIHJldHVybiBCb29sZWFuKHBhcmVudExpbmtFbGVtZW50Py5ocmVmPy5pbmNsdWRlcyhcIi93YXRjaD92PVwiKSlcbiAgfVxuXG4gIC8qKlxuICAgKiBSZXR1cm5zIHBhcmVudCBvZiBub2RlIHR5cGUuIE1heGltdW0gYWxsb3dlZCByZWN1cnNpdmUgZGVwdGggaXMgMTBcbiAgICpcbiAgICogQHN0YXRpY1xuICAgKiBAcGFyYW0ge0JlYW1FbGVtZW50fSBub2RlIHRhcmdldCBub2RlIHRvIHN0YXJ0IGF0XG4gICAqIEBwYXJhbSB7c3RyaW5nfSB0eXBlIHBhcmVudCB0eXBlIHRvIHNlYXJjaCBmb3JcbiAgICogQHBhcmFtIHtudW1iZXJ9IFtjb3VudD0xMF0gbWF4aW11bSBkZXB0aCBvZiByZWN1cnNpb24sIGRlZmF1bHRzIHRvIDEwXG4gICAqIEByZXR1cm4geyp9ICB7KEJlYW1FbGVtZW50IHwgdW5kZWZpbmVkKX1cbiAgICogQG1lbWJlcm9mIEJlYW1FbWJlZEhlbHBlclxuICAgKi9cbiAgaGFzUGFyZW50T2ZUeXBlKFxuICAgIGVsZW1lbnQ6IEJlYW1FbGVtZW50LFxuICAgIHR5cGU6IHN0cmluZyxcbiAgICBjb3VudCA9IDEwXG4gICk6IEJlYW1FbGVtZW50IHwgdW5kZWZpbmVkIHtcbiAgICBpZiAoY291bnQgPD0gMCkgcmV0dXJuIG51bGxcbiAgICBpZiAodHlwZSAhPT0gXCJCT0RZXCIgJiYgZWxlbWVudD8udGFnTmFtZSA9PT0gXCJCT0RZXCIpIHJldHVybiBudWxsXG4gICAgaWYgKCFlbGVtZW50Py5wYXJlbnRFbGVtZW50KSByZXR1cm4gbnVsbFxuICAgIGlmICh0eXBlID09PSBlbGVtZW50Py50YWdOYW1lKSByZXR1cm4gZWxlbWVudFxuICAgIGNvbnN0IG5ld0NvdW50ID0gY291bnQtLVxuICAgIHJldHVybiB0aGlzLmhhc1BhcmVudE9mVHlwZShlbGVtZW50LnBhcmVudEVsZW1lbnQsIHR5cGUsIG5ld0NvdW50KVxuICB9XG5cbiAgLyoqXG4gICAqIFBhcnNlIGh0bWwgZWxlbWVudCBpbnRvIGEgQW5jaG9ydGFnIGlmIGl0J3MgYSB5b3V0dWJlIHRodW1ibmFpbFxuICAgKlxuICAgKiBAcGFyYW0ge0JlYW1FbGVtZW50fSBlbGVtZW50XG4gICAqIEByZXR1cm4geyp9ICB7QmVhbUhUTUxFbGVtZW50fVxuICAgKiBAbWVtYmVyb2YgdGhpc1xuICAgKi9cbiAgcGFyc2VZb3VUdWJlVGh1bWJuYWlsRm9yRW1iZWQoZWxlbWVudDogQmVhbUVsZW1lbnQpOiBCZWFtSFRNTEVsZW1lbnQge1xuICAgIGlmICghdGhpcy5pc1lvdVR1YmVUaHVtYm5haWwoZWxlbWVudCkpIHtcbiAgICAgIHJldHVyblxuICAgIH1cblxuICAgIC8vIFdlIGFyZSBsb29raW5nIGZvciBhIHVybCBsaWtlOiAvd2F0Y2g/dj1EdEM4VHJjMkZlMFxuICAgIGlmIChlbGVtZW50Py5ocmVmPy5pbmNsdWRlcyhcIi93YXRjaD92PVwiKSkge1xuICAgICAgcmV0dXJuIHRoaXMuY3JlYXRlTGlua0VsZW1lbnQoZWxlbWVudD8uaHJlZilcbiAgICB9XG5cbiAgICAvLyBDaGVjayBwYXJlbnQgbGluayBlbGVtZW50XG4gICAgY29uc3QgcGFyZW50TGlua0VsZW1lbnQgPSB0aGlzLmhhc1BhcmVudE9mVHlwZShlbGVtZW50LCBcIkFcIiwgNSlcbiAgICBpZiAocGFyZW50TGlua0VsZW1lbnQ/LmhyZWY/LmluY2x1ZGVzKFwiL3dhdGNoP3Y9XCIpKSB7XG4gICAgICByZXR1cm4gdGhpcy5jcmVhdGVMaW5rRWxlbWVudChwYXJlbnRMaW5rRWxlbWVudD8uaHJlZilcbiAgICB9XG5cbiAgICByZXR1cm5cbiAgfVxuXG4gIC8qKlxuICAgKiBSZXR1cm4gQmVhbUhUTUxFbGVtZW50IG9mIGFuIEFuY2hvcnRhZyB3aXRoIHByb3ZpZGVkIGhyZWYgYXR0cmlidXRlXG4gICAqXG4gICAqIEBwYXJhbSB7c3RyaW5nfSBocmVmXG4gICAqIEByZXR1cm4geyp9ICB7QmVhbUhUTUxFbGVtZW50fVxuICAgKiBAbWVtYmVyb2YgdGhpc1xuICAgKi9cbiAgY3JlYXRlTGlua0VsZW1lbnQoaHJlZjogc3RyaW5nKTogQmVhbUhUTUxFbGVtZW50IHtcbiAgICBjb25zdCBhbmNob3IgPSB0aGlzLndpbi5kb2N1bWVudC5jcmVhdGVFbGVtZW50KFwiYVwiKVxuICAgIGFuY2hvci5zZXRBdHRyaWJ1dGUoXCJocmVmXCIsIGhyZWYpXG4gICAgYW5jaG9yLmlubmVyVGV4dCA9IGhyZWZcbiAgICByZXR1cm4gYW5jaG9yXG4gIH1cbn1cbiIsImltcG9ydCB7IEJlYW1Mb2dDYXRlZ29yeSwgQmVhbUxvZ0xldmVsLCBCZWFtV2luZG93LCBOYXRpdmUgfSBmcm9tIFwiQGJlYW0vbmF0aXZlLWJlYW10eXBlc1wiXG5cbmV4cG9ydCBjbGFzcyBCZWFtTG9nZ2VyIHtcbiAgbmF0aXZlOiBOYXRpdmU8YW55PlxuICBjYXRlZ29yeTogQmVhbUxvZ0NhdGVnb3J5XG5cbiAgY29uc3RydWN0b3Iod2luOiBCZWFtV2luZG93LCBjYXRlZ29yeTogQmVhbUxvZ0NhdGVnb3J5KSB7XG4gICAgY29uc3QgY29tcG9uZW50UHJlZml4ID0gXCJiZWFtX2xvZ2dlclwiXG4gICAgdGhpcy5uYXRpdmUgPSBuZXcgTmF0aXZlKHdpbiwgY29tcG9uZW50UHJlZml4KVxuICAgIHRoaXMuY2F0ZWdvcnkgPSBjYXRlZ29yeVxuICB9XG5cbiAgbG9nKC4uLmFyZ3M6IHVua25vd25bXSk6IHZvaWQge1xuICAgIGNvbnN0IGZvcm1hdHRlZE1lc3NhZ2UgPSB0aGlzLmNvbnZlcnRBcmdzVG9NZXNzYWdlKGFyZ3MpXG4gICAgdGhpcy5zZW5kTWVzc2FnZShmb3JtYXR0ZWRNZXNzYWdlLCBCZWFtTG9nTGV2ZWwubG9nKVxuICB9XG5cbiAgbG9nV2FybmluZyguLi5hcmdzOiB1bmtub3duW10pOiB2b2lkIHtcbiAgICBjb25zdCBmb3JtYXR0ZWRNZXNzYWdlID0gdGhpcy5jb252ZXJ0QXJnc1RvTWVzc2FnZShhcmdzKVxuICAgIHRoaXMuc2VuZE1lc3NhZ2UoZm9ybWF0dGVkTWVzc2FnZSwgQmVhbUxvZ0xldmVsLndhcm5pbmcpXG4gIH1cblxuICBsb2dEZWJ1ZyguLi5hcmdzOiB1bmtub3duW10pOiB2b2lkIHtcbiAgICBjb25zdCBmb3JtYXR0ZWRNZXNzYWdlID0gdGhpcy5jb252ZXJ0QXJnc1RvTWVzc2FnZShhcmdzKVxuICAgIHRoaXMuc2VuZE1lc3NhZ2UoZm9ybWF0dGVkTWVzc2FnZSwgQmVhbUxvZ0xldmVsLmRlYnVnKVxuICB9XG5cbiAgbG9nRXJyb3IoLi4uYXJnczogdW5rbm93bltdKTogdm9pZCB7XG4gICAgY29uc3QgZm9ybWF0dGVkTWVzc2FnZSA9IHRoaXMuY29udmVydEFyZ3NUb01lc3NhZ2UoYXJncylcbiAgICB0aGlzLnNlbmRNZXNzYWdlKGZvcm1hdHRlZE1lc3NhZ2UsIEJlYW1Mb2dMZXZlbC5lcnJvcilcbiAgfVxuXG4gIHByaXZhdGUgc2VuZE1lc3NhZ2UobWVzc2FnZTogc3RyaW5nLCBsZXZlbDogQmVhbUxvZ0xldmVsKTogdm9pZCB7XG4gICAgdGhpcy5uYXRpdmUuc2VuZE1lc3NhZ2UoXCJsb2dcIiwge1xuICAgICAgbWVzc2FnZSxcbiAgICAgIGxldmVsLFxuICAgICAgY2F0ZWdvcnk6IHRoaXMuY2F0ZWdvcnlcbiAgICB9KVxuICB9XG5cbiAgcHJpdmF0ZSBjb252ZXJ0QXJnc1RvTWVzc2FnZShhcmdzOiBPYmplY3QpOiBzdHJpbmcge1xuICAgIGNvbnN0IG1lc3NhZ2VBcmdzID0gT2JqZWN0LnZhbHVlcyhhcmdzKS5tYXAoKHZhbHVlKSA9PiB7XG4gICAgICBsZXQgc3RyXG4gICAgICBpZiAodHlwZW9mIHZhbHVlID09PSBcIm9iamVjdFwiKSB7XG4gICAgICAgIHRyeSB7XG4gICAgICAgICAgc3RyID0gSlNPTi5zdHJpbmdpZnkodmFsdWUpXG4gICAgICAgIH0gY2F0Y2ggKGVycm9yKSB7XG4gICAgICAgICAgY29uc29sZS5lcnJvcihlcnJvcilcbiAgICAgICAgfVxuICAgICAgfVxuICAgICAgaWYgKCFzdHIpIHtcbiAgICAgICAgc3RyID0gU3RyaW5nKHZhbHVlKVxuICAgICAgfVxuICAgICAgcmV0dXJuIHN0clxuICAgIH0pXG4gICAgcmV0dXJuIG1lc3NhZ2VBcmdzXG4gICAgICAubWFwKCh2KSA9PiB2LnN1YnN0cmluZygwLCAzMDAwKSkgLy8gTGltaXQgbXNnIHRvIDMwMDAgY2hhcnNcbiAgICAgIC5qb2luKFwiLCBcIilcbiAgfVxufVxuIiwiaW1wb3J0IHtCZWFtUmVjdH0gZnJvbSBcIkBiZWFtL25hdGl2ZS1iZWFtdHlwZXNcIlxuXG5leHBvcnQgY2xhc3MgQmVhbVJlY3RIZWxwZXIge1xuXG4gIHN0YXRpYyBmaWx0ZXJSZWN0QXJyYXlCeVJlY3RBcnJheShzb3VyY2VBcnJheTogQmVhbVJlY3RbXSwgZmlsdGVyQXJyYXk6IEJlYW1SZWN0W10pOiBCZWFtUmVjdFtdIHtcbiAgICByZXR1cm4gc291cmNlQXJyYXkuZmlsdGVyKChzb3VyY2VSZWN0KSA9PiB7XG4gICAgICAvLyBXaGVuIHJlY3QgbWF0Y2hlcyBhcnJheSByZXR1cm4gdHJ1ZSB0byBmaWx0ZXIgaXRcbiAgICAgIHJldHVybiB0aGlzLmRvUmVjdE1hdGNoZXNSZWN0c0luQXJyYXkoc291cmNlUmVjdCwgZmlsdGVyQXJyYXkpID09IGZhbHNlXG4gICAgfSlcbiAgfVxuICBcbiAgc3RhdGljIGRvUmVjdE1hdGNoZXNSZWN0c0luQXJyYXkoc291cmNlUmVjdDogQmVhbVJlY3QsIGZpbHRlckFycmF5OiBCZWFtUmVjdFtdKTogYm9vbGVhbiB7XG4gICAgcmV0dXJuIGZpbHRlckFycmF5LnNvbWUoKGZpbHRlclJlY3QpID0+IHtcbiAgICAgICAgcmV0dXJuIHRoaXMuZG9SZWN0c01hdGNoKHNvdXJjZVJlY3QsIGZpbHRlclJlY3QpXG4gICAgfSlcbiAgfVxuXG4gIHN0YXRpYyBkb1JlY3RzTWF0Y2gocmVjdDE6IEJlYW1SZWN0LCByZWN0MjogQmVhbVJlY3QpOiBib29sZWFuIHtcbiAgICByZXR1cm4gKFxuICAgICAgTWF0aC5yb3VuZChyZWN0MT8ueCkgPT0gTWF0aC5yb3VuZChyZWN0Mj8ueCkgJiZcbiAgICAgIE1hdGgucm91bmQocmVjdDE/LnkpID09IE1hdGgucm91bmQocmVjdDI/LnkpICYmXG4gICAgICBNYXRoLnJvdW5kKHJlY3QxPy5oZWlnaHQpID09IE1hdGgucm91bmQocmVjdDI/LmhlaWdodCkgJiZcbiAgICAgIE1hdGgucm91bmQocmVjdDE/LndpZHRoKSA9PSBNYXRoLnJvdW5kKHJlY3QyPy53aWR0aClcbiAgICApXG4gIH1cblxuICAvKipcbiAgICogUmV0dXJuIHRoZSBib3VuZGluZyByZWN0YW5nbGUgZm9yIHR3byBnaXZlbiByZWN0YW5nbGVzXG4gICAqXG4gICAqIEBwYXJhbSByZWN0MVxuICAgKiBAcGFyYW0gcmVjdDJcbiAgICovXG4gIHN0YXRpYyBib3VuZGluZ1JlY3QocmVjdDE6IEJlYW1SZWN0LCByZWN0MjogQmVhbVJlY3QpOiBCZWFtUmVjdCB7XG4gICAgY29uc3QgeCA9IE1hdGgubWluKHJlY3QxLngsIHJlY3QyLngpXG4gICAgY29uc3QgeSA9IE1hdGgubWluKHJlY3QxLnksIHJlY3QyLnkpXG4gICAgY29uc3Qgd2lkdGggPSBNYXRoLm1heChyZWN0MS54ICsgcmVjdDEud2lkdGgsIHJlY3QyLnggKyByZWN0Mi53aWR0aCkgLSB4XG4gICAgY29uc3QgaGVpZ2h0ID0gTWF0aC5tYXgocmVjdDEueSArIHJlY3QxLmhlaWdodCwgcmVjdDIueSArIHJlY3QyLmhlaWdodCkgLSB5XG4gICAgcmV0dXJuIHsgeCwgeSwgd2lkdGgsIGhlaWdodCB9XG4gIH1cblxuICAvKipcbiAgICogR2V0IHRoZSBpbnRlcnNlY3Rpb24gb2YgdHdvIGdpdmVuIHJlY3RhbmdsZXMsIHRoZSByZWN0YW5nbGVzIGNhbiBoYXZlIGluZmluaXRlIGRpbWVuc2lvbnNcbiAgICogKGZvciBpbnN0YW5jZSB3aGVuIGB4YCBhbmQgYHdpZHRoYCBwcm9wZXJ0aWVzIGFyZSByZXNwZWN0aXZlbHkgLUluZmluaXR5IGFuZCBJbmZpbml0eSlcbiAgICpcbiAgICogQHBhcmFtIHJlY3QxXG4gICAqIEBwYXJhbSByZWN0MlxuICAgKiBAcmV0dXJuIHtCZWFtUmVjdH0gaWYgdGhlIGludGVyc2VjdGlvbiBpcyBkZWZpbmVkXG4gICAqIEByZXR1cm4gdW5kZWZpbmVkIHdoZW4gbm8gaW50ZXJzZWN0aW9uIGV4aXN0XG4gICAqL1xuICBzdGF0aWMgaW50ZXJzZWN0aW9uKHJlY3QxOiBCZWFtUmVjdCwgcmVjdDI6IEJlYW1SZWN0KTogQmVhbVJlY3Qge1xuICAgIGNvbnN0IHggPSBNYXRoLm1heChyZWN0MS54LCByZWN0Mi54KVxuICAgIGNvbnN0IHkgPSBNYXRoLm1heChyZWN0MS55LCByZWN0Mi55KVxuXG4gICAgLy8gcmVjdHMgY2FuIGhhdmUgSW5maW5pdGUgZGltZW5zaW9ucywgaW4gd2hpY2ggY2FzZSBoYXZlIHRvIGZpbHRlciBvdXQgTmFOIHZhbHVlc1xuICAgIC8vIHNpbmNlIC1JbmZpbml0eSArIEluZmluaXR5IGlzIE5hTiAocmVjdC54ICsgcmVjdC53aWR0aCBvciByZWN0LnkgKyByZWN0LmhlaWdodClcbiAgICBjb25zdCB2YWxpZFgyID0gW3JlY3QxLnggKyByZWN0MS53aWR0aCwgcmVjdDIueCArIHJlY3QyLndpZHRoXS5maWx0ZXIodiA9PiAhaXNOYU4odikpXG4gICAgY29uc3QgeDIgPSBNYXRoLm1pbiguLi52YWxpZFgyKVxuICAgIGNvbnN0IHZhbGlkWTIgPSBbcmVjdDEueSArIHJlY3QxLmhlaWdodCwgcmVjdDIueSArIHJlY3QyLmhlaWdodF0uZmlsdGVyKHYgPT4gIWlzTmFOKHYpKVxuICAgIGNvbnN0IHkyID0gTWF0aC5taW4oLi4udmFsaWRZMilcblxuICAgIGlmICh4MiA+IHggJiYgeTIgPiB5KSB7XG4gICAgICByZXR1cm4geyB4LCB5LCB3aWR0aDogeDIgLSB4LCBoZWlnaHQ6IHkyIC0geSB9XG4gICAgfVxuICB9XG59XG4iLCJpbXBvcnQge1xuICBCZWFtQ29vcmRpbmF0ZXMsXG4gIEJlYW1FbGVtZW50LFxuICBCZWFtSFRNTEVsZW1lbnQsXG4gIEJlYW1Nb3VzZUxvY2F0aW9uLFxuICBCZWFtTm9kZSxcbiAgQmVhbU5vZGVUeXBlLFxuICBCZWFtUmFuZ2UsXG4gIEJlYW1SYW5nZUdyb3VwLFxuICBCZWFtU2VsZWN0aW9uLFxuICBCZWFtU2hvb3RHcm91cCxcbiAgQmVhbVRleHQsXG4gIEJlYW1XaW5kb3dcbn0gZnJvbSBcIkBiZWFtL25hdGl2ZS1iZWFtdHlwZXNcIlxuaW1wb3J0IHsgQmVhbUVsZW1lbnRIZWxwZXIgfSBmcm9tIFwiLi9CZWFtRWxlbWVudEhlbHBlclwiXG5pbXBvcnQgeyBCZWFtRW1iZWRIZWxwZXIgfSBmcm9tIFwiLi9CZWFtRW1iZWRIZWxwZXJcIlxuXG5leHBvcnQgY2xhc3MgUG9pbnRBbmRTaG9vdEhlbHBlciB7XG4gIC8qKlxuICAgKiBDaGVjayBpZiBzdHJpbmcgbWF0Y2hlcyBhbnkgaXRlbXMgaW4gYXJyYXkgb2Ygc3RyaW5ncy4gRm9yIGEgbWlub3IgcGVyZm9ybWFuY2VcbiAgICogaW1wcm92ZW1lbnQgd2UgY2hlY2sgZmlyc3QgaWYgdGhlIHN0cmluZyBpcyBhIHNpbmdsZSBjaGFyYWN0ZXIuXG4gICAqXG4gICAqIEBzdGF0aWNcbiAgICogQHBhcmFtIHtzdHJpbmd9IHRleHRcbiAgICogQHJldHVybiB7Kn0gIHtib29sZWFufSB0cnVlIGlmIHRleHQgbWF0Y2hlc1xuICAgKiBAbWVtYmVyb2YgUG9pbnRBbmRTaG9vdEhlbHBlclxuICAgKi9cbiAgc3RhdGljIGlzT25seU1hcmt1cENoYXIodGV4dDogc3RyaW5nKTogYm9vbGVhbiB7XG4gICAgaWYgKHRleHQubGVuZ3RoID09IDEpIHtcbiAgICAgIHJldHVybiBbXCLigKJcIiwgXCItXCIsIFwifFwiLCBcIuKAk1wiLCBcIuKAlFwiLCBcIsK3XCJdLmluY2x1ZGVzKHRleHQpXG4gICAgfSBlbHNlIHtcbiAgICAgIHJldHVybiBmYWxzZVxuICAgIH1cbiAgfVxuICAvKipcbiAgICogUmV0dXJucyB3aGV0aGVyIG9yIG5vdCBhIHRleHQgaXMgZGVlbWVkIHVzZWZ1bCBlbm91Z2ggYXMgYSBzaW5nbGUgdW5pdFxuICAgKiB3ZSBzaG91bGQgYmUgdmVyeSBjYXV0aW91cyB3aXRoIHdoYXQgd2UgZmlsdGVyIG91dCwgc28gaW5zdGVhZCBvZiByZWx5aW5nXG4gICAqIG9uIHRoZSB0ZXh0IGxlbmd0aCA+IDEgY2hhciB3ZSdyZSBqdXN0IGhhdmluZyBhIGJsYWNrbGlzdCBvZiBjaGFyYWN0ZXJzXG4gICAqXG4gICAqIEBwYXJhbSB0ZXh0XG4gICAqL1xuICBzdGF0aWMgaXNUZXh0TWVhbmluZ2Z1bCh0ZXh0OiBzdHJpbmcpOiBib29sZWFuIHtcbiAgICBpZiAodGV4dCkge1xuICAgICAgY29uc3QgdHJpbW1lZCA9IHRleHQudHJpbSgpXG4gICAgICByZXR1cm4gISF0cmltbWVkICYmICF0aGlzLmlzT25seU1hcmt1cENoYXIodHJpbW1lZClcbiAgICB9XG4gICAgcmV0dXJuIGZhbHNlXG4gIH1cbiAgLyoqXG4gICAqIENoZWNrcyBpZiBhbiBlbGVtZW50IG1lZXRzIHRoZSByZXF1aXJlbWVudHMgdG8gYmUgY29uc2lkZXJlZCBtZWFuaW5nZnVsXG4gICAqIHRvIGJlIGluY2x1ZGVkIHdpdGhpbiB0aGUgaGlnaGxpZ2h0ZWQgYXJlYS4gQW4gZWxlbWVudCBpcyBtZWFuaW5nZnVsIGlmXG4gICAqIGl0J3MgdmlzaWJsZSBhbmQgaWYgaXQncyBlaXRoZXIgYW4gaW1hZ2Ugb3IgaXQgaGFzIGF0IGxlYXN0IHNvbWUgYWN0dWFsXG4gICAqIHRleHQgY29udGVudFxuICAgKlxuICAgKiBAcGFyYW0gZWxlbWVudFxuICAgKiBAcGFyYW0gd2luXG4gICAqL1xuICBzdGF0aWMgaXNNZWFuaW5nZnVsKGVsZW1lbnQ6IEJlYW1FbGVtZW50LCB3aW46IEJlYW1XaW5kb3cpOiBib29sZWFuIHtcbiAgICBjb25zdCBlbWJlZEhlbHBlciA9IG5ldyBCZWFtRW1iZWRIZWxwZXIod2luKVxuICAgIHJldHVybiAoXG4gICAgICAoZW1iZWRIZWxwZXIuaXNFbWJlZGRhYmxlRWxlbWVudChlbGVtZW50KSB8fFxuICAgICAgICBCZWFtRWxlbWVudEhlbHBlci5pc01lZGlhKGVsZW1lbnQpIHx8XG4gICAgICAgIEJlYW1FbGVtZW50SGVscGVyLmlzSW1hZ2VDb250YWluZXIoZWxlbWVudCwgd2luKSB8fFxuICAgICAgICBQb2ludEFuZFNob290SGVscGVyLmlzVGV4dE1lYW5pbmdmdWwoQmVhbUVsZW1lbnRIZWxwZXIuZ2V0VGV4dFZhbHVlKGVsZW1lbnQpKSkgJiZcbiAgICAgIEJlYW1FbGVtZW50SGVscGVyLmlzVmlzaWJsZShlbGVtZW50LCB3aW4pXG4gICAgKVxuICB9XG4gIC8qKlxuICAgKiBSZXR1cm5zIHRydWUgaWYgZWxlbWVudCBtYXRjaGVzIGEga25vd24gaHRtbCB0byBpZ25vcmUgb24gc3BlY2lmaWMgdXJscy5cbiAgICpcbiAgICogQHN0YXRpY1xuICAgKiBAcGFyYW0ge0JlYW1FbGVtZW50fSBlbGVtZW50XG4gICAqIEBwYXJhbSB7QmVhbVdpbmRvd30gd2luXG4gICAqIEByZXR1cm4geyp9ICB7Ym9vbGVhbn0gdHJ1ZSBpZiBlbGVtZW50IHNob3VsZCBiZSBpZ25vcmVkXG4gICAqIEBtZW1iZXJvZiBQb2ludEFuZFNob290SGVscGVyXG4gICAqL1xuICBzdGF0aWMgaXNVc2VsZXNzU2l0ZVNwZWNpZmljRWxlbWVudChlbGVtZW50OiBCZWFtRWxlbWVudCwgd2luOiBCZWFtV2luZG93KTogYm9vbGVhbiB7XG4gICAgLy8gQW1hem9uIE1hZ25pZmllclxuICAgIGlmICh3aW4ubG9jYXRpb24uaG9zdG5hbWU/LmluY2x1ZGVzKFwiYW1hem9uLlwiKSAmJiBlbGVtZW50LmlkID09IFwibWFnbmlmaWVyTGVuc1wiKSB7XG4gICAgICByZXR1cm4gdHJ1ZVxuICAgIH1cblxuICAgIHJldHVybiBmYWxzZVxuICB9XG4gIC8qKlxuICAgKiBSZWN1cnNpdmVseSBjaGVjayBmb3IgdGhlIHByZXNlbmNlIG9mIGFueSBtZWFuaW5nZnVsIGNoaWxkIG5vZGVzIHdpdGhpbiBhIGdpdmVuIGVsZW1lbnRcbiAgICpcbiAgICogQHN0YXRpY1xuICAgKiBAcGFyYW0ge0JlYW1FbGVtZW50fSBlbGVtZW50IFRoZSBFbGVtZW50IHRvIHF1ZXJ5XG4gICAqIEBwYXJhbSB7QmVhbVdpbmRvd30gd2luXG4gICAqIEByZXR1cm4geyp9ICB7Ym9vbGVhbn0gQm9vbGVhbiBpZiBlbGVtZW50IG9yIGFueSBvZiBpdCdzIGNoaWxkcmVuIGFyZSBtZWFuaW5nZnVsXG4gICAqIEBtZW1iZXJvZiBQb2ludEFuZFNob290SGVscGVyXG4gICAqL1xuICBzdGF0aWMgaXNNZWFuaW5nZnVsT3JDaGlsZHJlbkFyZShlbGVtZW50OiBCZWFtRWxlbWVudCwgd2luOiBCZWFtV2luZG93KTogYm9vbGVhbiB7XG4gICAgaWYgKFBvaW50QW5kU2hvb3RIZWxwZXIuaXNNZWFuaW5nZnVsKGVsZW1lbnQsIHdpbikpIHtcbiAgICAgIHJldHVybiB0cnVlXG4gICAgfVxuICAgIHJldHVybiBbLi4uZWxlbWVudC5jaGlsZHJlbl0uc29tZSgoY2hpbGQpID0+IFBvaW50QW5kU2hvb3RIZWxwZXIuaXNNZWFuaW5nZnVsKGNoaWxkLCB3aW4pKVxuICB9XG4gIC8qKlxuICAgKiBSZWN1cnNpdmVseSBjaGVjayBmb3IgdGhlIHByZXNlbmNlIG9mIGFueSBtZWFuaW5nZnVsIGNoaWxkIG5vZGVzIHdpdGhpbiBhIGdpdmVuIGVsZW1lbnQuXG4gICAqXG4gICAqIEBzdGF0aWNcbiAgICogQHBhcmFtIHtCZWFtRWxlbWVudH0gZWxlbWVudCBUaGUgRWxlbWVudCB0byBxdWVyeVxuICAgKiBAcGFyYW0ge0JlYW1XaW5kb3d9IHdpblxuICAgKiBAcmV0dXJuIHsqfSAge0JlYW1Ob2RlW119IHJldHVybiB0aGUgZWxlbWVudCdzIG1lYW5pbmdmdWwgY2hpbGQgbm9kZXNcbiAgICogQG1lbWJlcm9mIFBvaW50QW5kU2hvb3RIZWxwZXJcbiAgICovXG4gIHN0YXRpYyBnZXRNZWFuaW5nZnVsQ2hpbGROb2RlcyhlbGVtZW50OiBCZWFtRWxlbWVudCwgd2luOiBCZWFtV2luZG93KTogQmVhbU5vZGVbXSB7XG4gICAgcmV0dXJuIFsuLi5lbGVtZW50LmNoaWxkTm9kZXNdLmZpbHRlcihcbiAgICAgIChjaGlsZCkgPT5cbiAgICAgICAgKGNoaWxkLm5vZGVUeXBlID09PSBCZWFtTm9kZVR5cGUuZWxlbWVudCAmJlxuICAgICAgICAgIFBvaW50QW5kU2hvb3RIZWxwZXIuaXNNZWFuaW5nZnVsT3JDaGlsZHJlbkFyZShjaGlsZCBhcyBCZWFtRWxlbWVudCwgd2luKSkgfHxcbiAgICAgICAgKGNoaWxkLm5vZGVUeXBlID09PSBCZWFtTm9kZVR5cGUudGV4dCAmJiBQb2ludEFuZFNob290SGVscGVyLmlzVGV4dE1lYW5pbmdmdWwoKGNoaWxkIGFzIEJlYW1UZXh0KS5kYXRhKSlcbiAgICApXG4gIH1cbiAgLyoqXG4gICAqIFJlY3Vyc2l2ZWx5IGNoZWNrIGZvciB0aGUgcHJlc2VuY2Ugb2YgYW55IFVzZWxlc3MgY2hpbGQgbm9kZXMgd2l0aGluIGEgZ2l2ZW4gZWxlbWVudFxuICAgKlxuICAgKiBAc3RhdGljXG4gICAqIEBwYXJhbSB7QmVhbUVsZW1lbnR9IGVsZW1lbnQgVGhlIEVsZW1lbnQgdG8gcXVlcnlcbiAgICogQHBhcmFtIHtCZWFtV2luZG93fSB3aW5cbiAgICogQHJldHVybiB7Kn0gIHtib29sZWFufSBCb29sZWFuIGlmIGVsZW1lbnQgb3IgYW55IG9mIGl0J3MgY2hpbGRyZW4gYXJlIFVzZWxlc3NcbiAgICogQG1lbWJlcm9mIFBvaW50QW5kU2hvb3RIZWxwZXJcbiAgICovXG4gIHN0YXRpYyBpc1VzZWxlc3NPckNoaWxkcmVuQXJlKGVsZW1lbnQ6IEJlYW1FbGVtZW50LCB3aW46IEJlYW1XaW5kb3cpOiBib29sZWFuIHtcbiAgICByZXR1cm4gUG9pbnRBbmRTaG9vdEhlbHBlci5pc01lYW5pbmdmdWxPckNoaWxkcmVuQXJlKGVsZW1lbnQsIHdpbikgPT0gZmFsc2VcbiAgfVxuICAvKipcbiAgICogR2V0IGFsbCBjaGlsZCBub2RlcyBvZiB0eXBlIGVsZW1lbnQgb3IgdGV4dFxuICAgKlxuICAgKiBAc3RhdGljXG4gICAqIEBwYXJhbSB7QmVhbUVsZW1lbnR9IGVsZW1lbnRcbiAgICogQHBhcmFtIHtCZWFtV2luZG93fSB3aW5cbiAgICogQHJldHVybiB7Kn0gIHtCZWFtTm9kZVtdfVxuICAgKiBAbWVtYmVyb2YgUG9pbnRBbmRTaG9vdEhlbHBlclxuICAgKi9cbiAgc3RhdGljIGdldEVsZW1lbnRBbmRUZXh0Q2hpbGROb2Rlc1JlY3Vyc2l2ZWx5KGVsZW1lbnQ6IEJlYW1FbGVtZW50LCB3aW46IEJlYW1XaW5kb3cpOiBCZWFtTm9kZVtdIHtcbiAgICBpZiAoIWVsZW1lbnQ/LmNoaWxkTm9kZXMpIHtcbiAgICAgIHJldHVybiBbZWxlbWVudF1cbiAgICB9XG5cbiAgICBjb25zdCBub2RlcyA9IFtdO1xuXG4gICAgWy4uLmVsZW1lbnQuY2hpbGROb2Rlc10uZm9yRWFjaCgoY2hpbGQpID0+IHtcbiAgICAgIHN3aXRjaCAoY2hpbGQubm9kZVR5cGUpIHtcbiAgICAgICAgY2FzZSBCZWFtTm9kZVR5cGUuZWxlbWVudDpcbiAgICAgICAgICBub2Rlcy5wdXNoKGNoaWxkKVxuICAgICAgICAgIC8vIGVzbGludC1kaXNhYmxlLW5leHQtbGluZSBuby1jYXNlLWRlY2xhcmF0aW9uc1xuICAgICAgICAgIGNvbnN0IGNoaWxkTm9kZXNPZkNoaWxkID0gdGhpcy5nZXRFbGVtZW50QW5kVGV4dENoaWxkTm9kZXNSZWN1cnNpdmVseShjaGlsZCBhcyBCZWFtRWxlbWVudCwgd2luKVxuICAgICAgICAgIG5vZGVzLnB1c2goLi4uY2hpbGROb2Rlc09mQ2hpbGQpXG4gICAgICAgICAgYnJlYWtcbiAgICAgICAgY2FzZSBCZWFtTm9kZVR5cGUudGV4dDpcbiAgICAgICAgICBub2Rlcy5wdXNoKGNoaWxkKVxuICAgICAgICAgIGJyZWFrXG4gICAgICAgIGRlZmF1bHQ6XG4gICAgICAgICAgYnJlYWtcbiAgICAgIH1cbiAgICB9KVxuXG4gICAgaWYgKG5vZGVzLmxlbmd0aCA9PSAwKSB7XG4gICAgICByZXR1cm4gW2VsZW1lbnRdXG4gICAgfVxuXG4gICAgcmV0dXJuIG5vZGVzXG4gIH1cblxuICAvKipcbiAgICogUmV0dXJucyB0cnVlIGlmIG9ubHkgdGhlIGFsdEtleSBpcyBwcmVzc2VkLiBBbHQgaXMgZXF1YWwgdG8gT3B0aW9uIGlzIE1hY09TLlxuICAgKlxuICAgKiBAc3RhdGljXG4gICAqIEBwYXJhbSB7Kn0gZXZcbiAgICogQHJldHVybiB7Kn0gIHtib29sZWFufVxuICAgKiBAbWVtYmVyb2YgUG9pbnRBbmRTaG9vdEhlbHBlclxuICAgKi9cbiAgc3RhdGljIGlzT25seUFsdEtleShldik6IGJvb2xlYW4ge1xuICAgIGNvbnN0IGFsdEtleSA9IGV2LmFsdEtleSB8fCBldi5rZXkgPT0gXCJBbHRcIlxuICAgIHJldHVybiBhbHRLZXkgJiYgIWV2LmN0cmxLZXkgJiYgIWV2Lm1ldGFLZXkgJiYgIWV2LnNoaWZ0S2V5XG4gIH1cblxuICBzdGF0aWMgdXBzZXJ0U2hvb3RHcm91cChuZXdJdGVtOiBCZWFtU2hvb3RHcm91cCwgZ3JvdXBzOiBCZWFtU2hvb3RHcm91cFtdKTogdm9pZCB7XG4gICAgLy8gVXBkYXRlIGV4aXN0aW5nIHJhbmdlR3JvdXBcbiAgICBjb25zdCBpbmRleCA9IGdyb3Vwcy5maW5kSW5kZXgoKHsgZWxlbWVudCB9KSA9PiB7XG4gICAgICByZXR1cm4gZWxlbWVudCA9PSBuZXdJdGVtLmVsZW1lbnRcbiAgICB9KVxuICAgIGlmIChpbmRleCAhPSAtMSkge1xuICAgICAgZ3JvdXBzW2luZGV4XSA9IG5ld0l0ZW1cbiAgICB9IGVsc2Uge1xuICAgICAgZ3JvdXBzLnB1c2gobmV3SXRlbSlcbiAgICB9XG4gIH1cblxuICBzdGF0aWMgdXBzZXJ0UmFuZ2VHcm91cChuZXdJdGVtOiBCZWFtUmFuZ2VHcm91cCwgZ3JvdXBzOiBCZWFtUmFuZ2VHcm91cFtdKTogdm9pZCB7XG4gICAgLy8gVXBkYXRlIGV4aXN0aW5nIHJhbmdlR3JvdXBcbiAgICBjb25zdCBpbmRleCA9IGdyb3Vwcy5maW5kSW5kZXgoKHsgaWQgfSkgPT4ge1xuICAgICAgcmV0dXJuIGlkID09IG5ld0l0ZW0uaWRcbiAgICB9KVxuICAgIGlmIChpbmRleCAhPSAtMSkge1xuICAgICAgZ3JvdXBzW2luZGV4XSA9IG5ld0l0ZW1cbiAgICB9IGVsc2Uge1xuICAgICAgZ3JvdXBzLnB1c2gobmV3SXRlbSlcbiAgICB9XG4gIH1cbiAgLyoqXG4gICAqIFJldHVybnMgdHJ1ZSB3aGVuIHRoZSB0YXJnZXQgaGFzIGBjb250ZW50ZWRpdGFibGU9XCJ0cnVlXCJgIG9yIGBjb250ZW50ZWRpdGFibGU9XCJwbGFpbnRleHQtb25seVwiYFxuICAgKlxuICAgKiBAc3RhdGljXG4gICAqIEBwYXJhbSB7QmVhbUhUTUxFbGVtZW50fSB0YXJnZXRcbiAgICogQHJldHVybiB7Kn0gIHtib29sZWFufVxuICAgKiBAbWVtYmVyb2YgUG9pbnRBbmRTaG9vdEhlbHBlclxuICAgKi9cbiAgc3RhdGljIGlzRXhwbGljaXRseUNvbnRlbnRFZGl0YWJsZSh0YXJnZXQ6IEJlYW1IVE1MRWxlbWVudCk6IGJvb2xlYW4ge1xuICAgIHJldHVybiBbXCJ0cnVlXCIsIFwicGxhaW50ZXh0LW9ubHlcIl0uaW5jbHVkZXMoQmVhbUVsZW1lbnRIZWxwZXIuZ2V0Q29udGVudEVkaXRhYmxlKHRhcmdldCkpXG4gIH1cbiAgLyoqXG4gICAqIENoZWNrIGZvciBpbmhlcml0ZWQgY29udGVudGVkaXRhYmxlIGF0dHJpYnV0ZSB2YWx1ZSBieSB0cmF2ZXJzaW5nXG4gICAqIHRoZSBhbmNlc3RvcnMgdW50aWwgYW4gZXhwbGljaXRseSBzZXQgdmFsdWUgaXMgZm91bmRcbiAgICpcbiAgICogQHBhcmFtIGVsZW1lbnQgeyhCZWFtTm9kZSl9IFRoZSBET00gbm9kZSB0byBjaGVjay5cbiAgICogQHJldHVybiBJZiB0aGUgZWxlbWVudCBpbmhlcml0cyBmcm9tIGFuIGFjdHVhbCBjb250ZW50ZWRpdGFibGUgdmFsaWQgdmFsdWVzXG4gICAqICAgICAgICAgKFwidHJ1ZVwiLCBcInBsYWludGV4dC1vbmx5XCIpXG4gICAqL1xuICBzdGF0aWMgZ2V0SW5oZXJpdGVkQ29udGVudEVkaXRhYmxlKGVsZW1lbnQ6IEJlYW1IVE1MRWxlbWVudCk6IGJvb2xlYW4ge1xuICAgIGxldCBpc0VkaXRhYmxlID0gdGhpcy5pc0V4cGxpY2l0bHlDb250ZW50RWRpdGFibGUoZWxlbWVudClcbiAgICBjb25zdCBwYXJlbnQgPSBlbGVtZW50LnBhcmVudEVsZW1lbnQgYXMgQmVhbUhUTUxFbGVtZW50XG4gICAgaWYgKHBhcmVudCAmJiBCZWFtRWxlbWVudEhlbHBlci5nZXRDb250ZW50RWRpdGFibGUoZWxlbWVudCkgPT09IFwiaW5oZXJpdFwiKSB7XG4gICAgICBpc0VkaXRhYmxlID0gdGhpcy5nZXRJbmhlcml0ZWRDb250ZW50RWRpdGFibGUocGFyZW50KVxuICAgIH1cbiAgICByZXR1cm4gaXNFZGl0YWJsZVxuICB9XG4gIC8qKlxuICAgKiBSZXR1cm5zIHRydWUgd2hlbiB0YXJnZXQgaXMgYSB0ZXh0IGlucHV0LiBTcGVjaWZpY2x5IHdoZW4gZWl0aGVyIG9mIHRoZXNlIGNvbmRpdGlvbnMgaXMgdHJ1ZTpcbiAgICogIC0gVGhlIHRhcmdldCBpcyBhbiB0ZXh0IDxpbnB1dD4gdGFnXG4gICAqICAtIFRoZSB0YXJnZXQgb3IgaXQncyBwYXJlbnQgZWxlbWVudCBpcyBjb250ZW50RWRpdGFibGVcbiAgICpcbiAgICogQHN0YXRpY1xuICAgKiBAcGFyYW0ge0JlYW1IVE1MRWxlbWVudH0gdGFyZ2V0XG4gICAqIEByZXR1cm4geyp9ICB7Ym9vbGVhbn1cbiAgICogQG1lbWJlcm9mIFBvaW50QW5kU2hvb3RIZWxwZXJcbiAgICovXG4gIHN0YXRpYyBpc1RhcmdldFRleHR1YWxJbnB1dCh0YXJnZXQ6IEJlYW1IVE1MRWxlbWVudCk6IGJvb2xlYW4ge1xuICAgIHJldHVybiBCZWFtRWxlbWVudEhlbHBlci5pc1RleHR1YWxJbnB1dFR5cGUodGFyZ2V0KSB8fCB0aGlzLmdldEluaGVyaXRlZENvbnRlbnRFZGl0YWJsZSh0YXJnZXQpXG4gIH1cblxuICAvKipcbiAgICogUmV0dXJucyB0cnVlIHdoZW4gdGhlIFRhcmdldCBlbGVtZW50IGlzIHRoZSBhY3RpdmVFbGVtZW50LiBJdCBhbHdheXMgcmV0dXJucyBmYWxzZSB3aGVuIHRoZSB0YXJnZXQgRWxlbWVudCBpcyB0aGUgZG9jdW1lbnQgYm9keS5cbiAgICpcbiAgICogQHN0YXRpY1xuICAgKiBAcGFyYW0ge0JlYW1XaW5kb3d9IHdpblxuICAgKiBAcGFyYW0ge0JlYW1IVE1MRWxlbWVudH0gdGFyZ2V0XG4gICAqIEByZXR1cm4geyp9ICB7Ym9vbGVhbn1cbiAgICogQG1lbWJlcm9mIFBvaW50QW5kU2hvb3RIZWxwZXJcbiAgICovXG4gIHN0YXRpYyBpc0V2ZW50VGFyZ2V0QWN0aXZlKHdpbjogQmVhbVdpbmRvdywgdGFyZ2V0OiBCZWFtSFRNTEVsZW1lbnQpOiBib29sZWFuIHtcbiAgICByZXR1cm4gISEoXG4gICAgICB3aW4uZG9jdW1lbnQuYWN0aXZlRWxlbWVudCAmJlxuICAgICAgd2luLmRvY3VtZW50LmFjdGl2ZUVsZW1lbnQgIT09IHdpbi5kb2N1bWVudC5ib2R5ICYmXG4gICAgICB3aW4uZG9jdW1lbnQuYWN0aXZlRWxlbWVudC5jb250YWlucyh0YXJnZXQpXG4gICAgKVxuICB9XG4gIC8qKlxuICAgKiBSZXR1cm5zIHRydWUgd2hlbiB0aGUgVGFyZ2V0IFRleHQgRWxlbWVudCBpcyB0aGUgYWN0aXZlRWxlbWVudCAoVGhlIGN1cnJlbnQgZWxlbWVudCB3aXRoIFwiRm9jdXNcIilcbiAgICpcbiAgICogQHN0YXRpY1xuICAgKiBAcGFyYW0ge0JlYW1XaW5kb3d9IHdpblxuICAgKiBAcGFyYW0ge0JlYW1IVE1MRWxlbWVudH0gdGFyZ2V0XG4gICAqIEByZXR1cm4geyp9ICB7Ym9vbGVhbn1cbiAgICogQG1lbWJlcm9mIFBvaW50QW5kU2hvb3RIZWxwZXJcbiAgICovXG4gIHN0YXRpYyBpc0FjdGl2ZVRleHR1YWxJbnB1dCh3aW46IEJlYW1XaW5kb3csIHRhcmdldDogQmVhbUhUTUxFbGVtZW50KTogYm9vbGVhbiB7XG4gICAgcmV0dXJuIHRoaXMuaXNFdmVudFRhcmdldEFjdGl2ZSh3aW4sIHRhcmdldCkgJiYgdGhpcy5pc1RhcmdldFRleHR1YWxJbnB1dCh0YXJnZXQpXG4gIH1cbiAgLyoqXG4gICAqIENoZWNrcyBpZiB0aGUgTW91c2VMb2NhdGlvbiBDb29yZGluYXRlcyBoYXMgY2hhbmdlZCBmcm9tIHRoZSBwcm92aWRlZCBYIG9yIFkgQ29vcmRpbmF0ZXMuIFJldHVybnMgdHJ1ZSB3aGVuIGVpdGhlciBYIG9yIFkgaXMgZGlmZmVyZW50XG4gICAqXG4gICAqIEBzdGF0aWNcbiAgICogQHBhcmFtIHtCZWFtTW91c2VMb2NhdGlvbn0gbW91c2VMb2NhdGlvblxuICAgKiBAcGFyYW0ge251bWJlcn0gY2xpZW50WFxuICAgKiBAcGFyYW0ge251bWJlcn0gY2xpZW50WVxuICAgKiBAcmV0dXJuIHsqfSAge2Jvb2xlYW59XG4gICAqIEBtZW1iZXJvZiBQb2ludEFuZFNob290SGVscGVyXG4gICAqL1xuICBzdGF0aWMgaGFzTW91c2VMb2NhdGlvbkNoYW5nZWQobW91c2VMb2NhdGlvbjogQmVhbU1vdXNlTG9jYXRpb24sIGNsaWVudFg6IG51bWJlciwgY2xpZW50WTogbnVtYmVyKTogYm9vbGVhbiB7XG4gICAgcmV0dXJuIG1vdXNlTG9jYXRpb24/LnggIT09IGNsaWVudFggfHwgbW91c2VMb2NhdGlvbj8ueSAhPT0gY2xpZW50WVxuICB9XG4gIC8qKlxuICAgKiBSZXR1cm5zIHRydWUgd2hlbiB0aGUgY3VycmVudCBkb2N1bWVudCBoYXMgYW4gVGV4dCBJbnB1dCBvciBDb250ZW50RWRpdGFibGUgZWxlbWVudCBhcyBhY3RpdmVFbGVtZW50IChUaGUgY3VycmVudCBlbGVtZW50IHdpdGggXCJGb2N1c1wiKVxuICAgKlxuICAgKiBAc3RhdGljXG4gICAqIEBwYXJhbSB7QmVhbVdpbmRvd30gd2luXG4gICAqIEByZXR1cm4geyp9ICB7Ym9vbGVhbn1cbiAgICogQG1lbWJlcm9mIFBvaW50QW5kU2hvb3RIZWxwZXJcbiAgICovXG4gIHN0YXRpYyBoYXNGb2N1c2VkVGV4dHVhbElucHV0KHdpbjogQmVhbVdpbmRvdyk6IGJvb2xlYW4ge1xuICAgIGNvbnN0IHRhcmdldCA9IHdpbi5kb2N1bWVudC5hY3RpdmVFbGVtZW50IGFzIHVua25vd24gYXMgQmVhbUhUTUxFbGVtZW50XG4gICAgaWYgKHRhcmdldCkge1xuICAgICAgcmV0dXJuICBCZWFtRWxlbWVudEhlbHBlci5pc1RleHR1YWxJbnB1dFR5cGUodGFyZ2V0KSB8fCB0aGlzLmdldEluaGVyaXRlZENvbnRlbnRFZGl0YWJsZSh0YXJnZXQpXG4gICAgfSBlbHNlIHtcbiAgICAgIHJldHVybiBmYWxzZVxuICAgIH1cbiAgfVxuICAvKipcbiAgICogUmV0dXJucyB0cnVlIHdoZW4gUG9pbnRpbmcgc2hvdWxkIGJlIGRpc2FibGVkLiBJdCBjaGVja3MgaWYgYW55IG9mIHRoZSBmb2xsb3dpbmcgaXMgdHJ1ZTpcbiAgICogIC0gVGhlIGV2ZW50IGlzIG9uIGFuIGFjdGl2ZSBUZXh0IElucHV0XG4gICAqICAtIFRoZSBkb2N1bWVudCBoYXMgYSBmb2N1c3NlZCBUZXh0IElucHV0XG4gICAqICAtIFRoZSBkb2N1bWVudCBoYXMgYW4gYWN0aXZlIFRleHQgU2VsZWN0aW9uXG4gICAqXG4gICAqIEBzdGF0aWNcbiAgICogQHBhcmFtIHtCZWFtV2luZG93fSB3aW5cbiAgICogQHBhcmFtIHtCZWFtSFRNTEVsZW1lbnR9IHRhcmdldFxuICAgKiBAcmV0dXJuIHsqfSAge2Jvb2xlYW59XG4gICAqIEBtZW1iZXJvZiBQb2ludEFuZFNob290SGVscGVyXG4gICAqL1xuICBzdGF0aWMgaXNQb2ludERpc2FibGVkKHdpbjogQmVhbVdpbmRvdywgdGFyZ2V0OiBCZWFtSFRNTEVsZW1lbnQpOiBib29sZWFuIHtcbiAgICByZXR1cm4gdGhpcy5pc0FjdGl2ZVRleHR1YWxJbnB1dCh3aW4sIHRhcmdldCkgfHwgdGhpcy5oYXNGb2N1c2VkVGV4dHVhbElucHV0KHdpbikgfHwgdGhpcy5oYXNTZWxlY3Rpb24od2luKVxuICB9XG4gIC8qKlxuICAgKiBSZXR1cm5zIGJvb2xlYW4gaWYgZG9jdW1lbnQgaGFzIGFjdGl2ZSBzZWxlY3Rpb25cbiAgICovXG4gIHN0YXRpYyBoYXNTZWxlY3Rpb24od2luOiBCZWFtV2luZG93KTogYm9vbGVhbiB7XG4gICAgcmV0dXJuICF3aW4uZG9jdW1lbnQuZ2V0U2VsZWN0aW9uKCkuaXNDb2xsYXBzZWQgJiYgQm9vbGVhbih3aW4uZG9jdW1lbnQuZ2V0U2VsZWN0aW9uKCkudG9TdHJpbmcoKSlcbiAgfVxuICAvKipcbiAgICogUmV0dXJucyBhbiBhcnJheSBvZiByYW5nZXMgZm9yIGEgZ2l2ZW4gSFRNTCBzZWxlY3Rpb25cbiAgICpcbiAgICogQHBhcmFtIHtCZWFtU2VsZWN0aW9ufSBzZWxlY3Rpb25cbiAgICogQHJldHVybiB7Kn0gIHtCZWFtUmFuZ2VbXX1cbiAgICovXG4gIHN0YXRpYyBnZXRTZWxlY3Rpb25SYW5nZXMoc2VsZWN0aW9uOiBCZWFtU2VsZWN0aW9uKTogQmVhbVJhbmdlW10ge1xuICAgIGNvbnN0IHJhbmdlcyA9IFtdXG4gICAgY29uc3QgY291bnQgPSBzZWxlY3Rpb24ucmFuZ2VDb3VudFxuICAgIGZvciAobGV0IGluZGV4ID0gMDsgaW5kZXggPCBjb3VudDsgKytpbmRleCkge1xuICAgICAgY29uc3QgcmFuZ2UgPSBzZWxlY3Rpb24uZ2V0UmFuZ2VBdChpbmRleClcbiAgICAgIHJhbmdlcy5wdXNoKHJhbmdlKVxuICAgIH1cbiAgICByZXR1cm4gcmFuZ2VzXG4gIH1cbiAgLyoqXG4gICAqIFJldHVybnMgdGhlIGN1cnJlbnQgYWN0aXZlICh0ZXh0KSBzZWxlY3Rpb24gb24gdGhlIGRvY3VtZW50XG4gICAqXG4gICAqIEByZXR1cm4ge0JlYW1TZWxlY3Rpb259XG4gICAqL1xuICBzdGF0aWMgZ2V0U2VsZWN0aW9uKHdpbjogQmVhbVdpbmRvdyk6IEJlYW1TZWxlY3Rpb24ge1xuICAgIHJldHVybiB3aW4uZG9jdW1lbnQuZ2V0U2VsZWN0aW9uKClcbiAgfVxuICAvKipcbiAgICogUmV0dXJucyB0aGUgSFRNTCBlbGVtZW50IHVuZGVyIHRoZSBjdXJyZW50IE1vdXNlIExvY2F0aW9uIENvb3JkaW5hdGVzXG4gICAqXG4gICAqIEBzdGF0aWNcbiAgICogQHBhcmFtIHtCZWFtV2luZG93fSB3aW5cbiAgICogQHBhcmFtIHtCZWFtTW91c2VMb2NhdGlvbn0gbW91c2VMb2NhdGlvblxuICAgKiBAcmV0dXJuIHsqfSAge0JlYW1IVE1MRWxlbWVudH1cbiAgICogQG1lbWJlcm9mIFBvaW50QW5kU2hvb3RIZWxwZXJcbiAgICovXG4gIHN0YXRpYyBnZXRFbGVtZW50QXRNb3VzZUxvY2F0aW9uKHdpbjogQmVhbVdpbmRvdywgbW91c2VMb2NhdGlvbjogQmVhbU1vdXNlTG9jYXRpb24pOiBCZWFtSFRNTEVsZW1lbnQge1xuICAgIHJldHVybiB3aW4uZG9jdW1lbnQuZWxlbWVudEZyb21Qb2ludChtb3VzZUxvY2F0aW9uLngsIG1vdXNlTG9jYXRpb24ueSlcbiAgfVxuXG4gIHN0YXRpYyBnZXRPZmZzZXQob2JqZWN0OiBCZWFtRWxlbWVudCwgb2Zmc2V0OiBCZWFtQ29vcmRpbmF0ZXMpOiB2b2lkIHtcbiAgICBpZiAob2JqZWN0KSB7XG4gICAgICBvZmZzZXQueCArPSBvYmplY3Qub2Zmc2V0TGVmdFxuICAgICAgb2Zmc2V0LnkgKz0gb2JqZWN0Lm9mZnNldFRvcFxuICAgICAgUG9pbnRBbmRTaG9vdEhlbHBlci5nZXRPZmZzZXQob2JqZWN0Lm9mZnNldFBhcmVudCwgb2Zmc2V0KVxuICAgIH1cbiAgfVxuXG4gIHN0YXRpYyBnZXRTY3JvbGxlZChvYmplY3Q6IEJlYW1FbGVtZW50LCBzY3JvbGxlZDogQmVhbUNvb3JkaW5hdGVzKTogdm9pZCB7XG4gICAgaWYgKG9iamVjdCkge1xuICAgICAgc2Nyb2xsZWQueCArPSBvYmplY3Quc2Nyb2xsTGVmdFxuICAgICAgc2Nyb2xsZWQueSArPSBvYmplY3Quc2Nyb2xsVG9wXG4gICAgICBpZiAob2JqZWN0LnRhZ05hbWUudG9Mb3dlckNhc2UoKSAhPSBcImh0bWxcIikge1xuICAgICAgICBQb2ludEFuZFNob290SGVscGVyLmdldFNjcm9sbGVkKG9iamVjdC5wYXJlbnROb2RlIGFzIEJlYW1FbGVtZW50LCBzY3JvbGxlZClcbiAgICAgIH1cbiAgICB9XG4gIH1cblxuICAvKipcbiAgICogR2V0IHRvcCBsZWZ0IFgsIFkgY29vcmRpbmF0ZXMgb2YgZWxlbWVudCB0YWtpbmcgaW50byBhY29jdW50IHRoZSBzY3JvbGwgcG9zaXRpb24gXG4gICAqXG4gICAqIEBzdGF0aWNcbiAgICogQHBhcmFtIHtCZWFtRWxlbWVudH0gZWxcbiAgICogQHJldHVybiB7Kn0gIHtCZWFtQ29vcmRpbmF0ZXN9XG4gICAqIEBtZW1iZXJvZiBVdGlsXG4gICAqL1xuICBzdGF0aWMgZ2V0VG9wTGVmdChlbDogQmVhbUVsZW1lbnQpOiBCZWFtQ29vcmRpbmF0ZXMge1xuICAgIGNvbnN0IG9mZnNldCA9IHsgeDogMCwgeTogMCB9XG4gICAgUG9pbnRBbmRTaG9vdEhlbHBlci5nZXRPZmZzZXQoZWwsIG9mZnNldClcblxuICAgIGNvbnN0IHNjcm9sbGVkID0geyB4OiAwLCB5OiAwIH1cbiAgICBQb2ludEFuZFNob290SGVscGVyLmdldFNjcm9sbGVkKGVsLnBhcmVudE5vZGUgYXMgQmVhbUVsZW1lbnQsIHNjcm9sbGVkKVxuXG4gICAgY29uc3QgeCA9IG9mZnNldC54IC0gc2Nyb2xsZWQueFxuICAgIGNvbnN0IHkgPSBvZmZzZXQueSAtIHNjcm9sbGVkLnlcbiAgICByZXR1cm4geyB4LCB5IH1cbiAgfVxuXG4gIC8qKlxuICAgKiBSZXR1cm4gdmFsdWUgY2xhbXBlZCBiZXR3ZWVuIG1pbiBhbmQgbWF4XG4gICAqXG4gICAqIEBzdGF0aWNcbiAgICogQHBhcmFtIHtudW1iZXJ9IHZhbFxuICAgKiBAcGFyYW0ge251bWJlcn0gbWluXG4gICAqIEBwYXJhbSB7bnVtYmVyfSBtYXhcbiAgICogQHJldHVybiB7bnVtYmVyfVxuICAgKiBAbWVtYmVyb2YgVXRpbFxuICAgKi9cbiAgc3RhdGljIGNsYW1wKHZhbDogbnVtYmVyLCBtaW46IG51bWJlciwgbWF4OiBudW1iZXIpOiBudW1iZXIge1xuICAgIHJldHVybiB2YWwgPiBtYXggPyBtYXggOiB2YWwgPCBtaW4gPyBtaW4gOiB2YWxcbiAgfVxuXG4gIC8qKlxuICAgKiBSZW1vdmUgbnVsbCBhbmQgdW5kZWZpbmVkIGZyb20gYXJyYXlcbiAgICpcbiAgICogQHN0YXRpY1xuICAgKiBAcGFyYW0ge3Vua25vd25bXX0gYXJyYXlcbiAgICogQHJldHVybiB7Kn0gIHthbnlbXX1cbiAgICogQG1lbWJlcm9mIFV0aWxcbiAgICovXG4gIHN0YXRpYyBjb21wYWN0KGFycmF5OiBhbnlbXSk6IGFueVtdIHtcbiAgICByZXR1cm4gYXJyYXkuZmlsdGVyKChpdGVtKSA9PiB7XG4gICAgICByZXR1cm4gaXRlbSAhPSBudWxsXG4gICAgfSlcbiAgfVxuXG4gIC8qKlxuICAgKiBDaGVjayBpZiBudW1iZXIgaXMgaW4gcmFuZ2VcbiAgICpcbiAgICogQHN0YXRpY1xuICAgKiBAcGFyYW0ge251bWJlcn0gbnVtYmVyIFRoZSBudW1iZXIgdG8gY2hlY2suXG4gICAqIEBwYXJhbSB7bnVtYmVyfSBzdGFydCBUaGUgc3RhcnQgb2YgdGhlIHJhbmdlLlxuICAgKiBAcGFyYW0ge251bWJlcn0gZW5kIFRoZSBlbmQgb2YgdGhlIHJhbmdlLlxuICAgKiBAcmV0dXJucyB7Ym9vbGVhbn0gUmV0dXJucyBgdHJ1ZWAgaWYgYG51bWJlcmAgaXMgaW4gdGhlIHJhbmdlLCBlbHNlIGBmYWxzZWAuXG4gICAqIEBtZW1iZXJvZiBVdGlsXG4gICAqL1xuICBzdGF0aWMgaXNOdW1iZXJJblJhbmdlKG51bWJlcjogbnVtYmVyLCBzdGFydDogbnVtYmVyLCBlbmQ6IG51bWJlcik6IGJvb2xlYW4ge1xuICAgIHJldHVybiBOdW1iZXIobnVtYmVyKSA+PSBNYXRoLm1pbihzdGFydCwgZW5kKSAmJiBudW1iZXIgPD0gTWF0aC5tYXgoc3RhcnQsIGVuZClcbiAgfVxuXG4gIC8qKlxuICAgKiBNYXBzIHZhbHVlLCBmcm9tIHJhbmdlIHRvIHJhbmdlXG4gICAqXG4gICAqIEZvciBleGFtcGxlIG1hcHBpbmcgMTAgZGVncmVlcyBDZWxjaXVzIHRvIEZhaHJlbmhlaXRcbiAgICogYG1hcFJhbmdlVG9SYW5nZShbMCwgMTAwXSwgWzMyLCAyMTJdLCAxMClgXG4gICAqXG4gICAqIEBzdGF0aWNcbiAgICogQHBhcmFtIHtbbnVtYmVyLCBudW1iZXJdfSBmcm9tXG4gICAqIEBwYXJhbSB7W251bWJlciwgbnVtYmVyXX0gdG9cbiAgICogQHBhcmFtIHtudW1iZXJ9IHNcbiAgICogQHJldHVybiB7Kn0gIHtudW1iZXJ9XG4gICAqIEBtZW1iZXJvZiBVdGlsXG4gICAqL1xuICBzdGF0aWMgbWFwUmFuZ2VUb1JhbmdlKGZyb206IFtudW1iZXIsIG51bWJlcl0sIHRvOiBbbnVtYmVyLCBudW1iZXJdLCBzOiBudW1iZXIpOiBudW1iZXIge1xuICAgIHJldHVybiB0b1swXSArICgocyAtIGZyb21bMF0pICogKHRvWzFdIC0gdG9bMF0pKSAvIChmcm9tWzFdIC0gZnJvbVswXSlcbiAgfVxuXG4gIC8qKlxuICAgKiBHZW5lcmF0ZXMgYSBnb29kIGVub3VnaCBub24tY29tcGxpYW50IFVVSUQuXG4gICAqXG4gICAqIEBzdGF0aWNcbiAgICogQHBhcmFtIHtCZWFtV2luZG93fSB3aW5cbiAgICogQHJldHVybiB7Kn0gIHtzdHJpbmd9XG4gICAqIEBtZW1iZXJvZiBVdGlsXG4gICAqL1xuICBzdGF0aWMgdXVpZCh3aW46IEJlYW1XaW5kb3c8YW55Pik6IHN0cmluZyB7XG4gICAgY29uc3QgYnVmID0gbmV3IFVpbnQzMkFycmF5KDQpXG4gICAgcmV0dXJuIHdpbi5jcnlwdG8uZ2V0UmFuZG9tVmFsdWVzKGJ1Zikuam9pbihcIi1cIilcbiAgfVxuXG4gIC8qKlxuICAgKiBSZW1vdmUgZmlyc3QgbWF0Y2hlZCBpdGVtIGZyb20gYXJyYXksIFVzZXMgZmluZEluZGV4IHVuZGVyIHRoZSBob29kLlxuICAgKlxuICAgKiBAc3RhdGljXG4gICAqIEBwYXJhbSB7KGFycmF5RWxlbWVudCkgPT4gYm9vbGVhbn0gbWF0Y2hlciB3aGVuIG1hdGNoZXIgcmV0dXJucyB0cnVlIHRoYXQgaXRlbSBpcyByZW1vdmVkIGZyb20gYXJyYXlcbiAgICogQHBhcmFtIHt1bmtub3duW119IGFycmF5IGlucHV0IGFycmF5XG4gICAqIEByZXR1cm4geyp9ICB7dW5rbm93bltdfSByZXR1cm4gdXBkYXRlZCBhcnJheVxuICAgKiBAbWVtYmVyb2YgVXRpbFxuICAgKi9cbiAgc3RhdGljIHJlbW92ZUZyb21BcnJheShtYXRjaGVyOiAoYXJyYXlFbGVtZW50KSA9PiBib29sZWFuLCBhcnJheTogdW5rbm93bltdKTogdW5rbm93bltdIHtcbiAgICBjb25zdCBmb3VuZEluZGV4ID0gYXJyYXkuZmluZEluZGV4KG1hdGNoZXIpXG4gICAgLy8gZm91bmRJbmRleCBpcyAtMSB3aGVuIG5vIG1hdGNoIGlzIGZvdW5kLiBPbmx5IHJlbW92ZSBmb3VuZCBpdGVtcyBmcm9tIGFycmF5XG4gICAgaWYgKGZvdW5kSW5kZXggPj0gMCkge1xuICAgICAgYXJyYXkuc3BsaWNlKGZvdW5kSW5kZXgsIDEpXG4gICAgfVxuXG4gICAgcmV0dXJuIGFycmF5XG4gIH1cbn1cbiIsImltcG9ydCB7IEJlYW1Mb2dnZXIgfSBmcm9tIFwiLi9CZWFtTG9nZ2VyXCJcbmltcG9ydCB7IEJlYW1SZWN0SGVscGVyIH0gZnJvbSBcIi4vQmVhbVJlY3RIZWxwZXJcIlxuaW1wb3J0IHsgQmVhbUVtYmVkSGVscGVyIH0gZnJvbSBcIi4vQmVhbUVtYmVkSGVscGVyXCJcbmltcG9ydCB7IEJlYW1FbGVtZW50SGVscGVyIH0gZnJvbSBcIi4vQmVhbUVsZW1lbnRIZWxwZXJcIlxuaW1wb3J0IHsgUG9pbnRBbmRTaG9vdEhlbHBlciB9IGZyb20gXCIuL1BvaW50QW5kU2hvb3RIZWxwZXJcIlxuXG5leHBvcnQge1xuICBCZWFtTG9nZ2VyLFxuICBCZWFtUmVjdEhlbHBlcixcbiAgQmVhbUVtYmVkSGVscGVyLFxuICBCZWFtRWxlbWVudEhlbHBlcixcbiAgUG9pbnRBbmRTaG9vdEhlbHBlclxufVxuXG4iLCJpbXBvcnQge1xuICBCZWFtTG9nQ2F0ZWdvcnksXG4gIEJlYW1XaW5kb3csXG4gIEJlYW1VSUV2ZW50XG59IGZyb20gXCJAYmVhbS9uYXRpdmUtYmVhbXR5cGVzXCJcbmltcG9ydCB7IEJlYW1Mb2dnZXIgfSBmcm9tIFwiQGJlYW0vbmF0aXZlLXV0aWxzXCJcbmltcG9ydCB7IFBhc3N3b3JkTWFuYWdlclVJIH0gZnJvbSBcIi4vUGFzc3dvcmRNYW5hZ2VyVUlcIlxuaW1wb3J0IHsgUGFzc3dvcmRNYW5hZ2VySGVscGVyIH0gZnJvbSBcIi4vUGFzc3dvcmRNYW5hZ2VySGVscGVyXCJcbmltcG9ydCB7ZGVxdWFsIGFzIGlzRGVlcEVxdWFsfSBmcm9tIFwiZGVxdWFsXCJcblxuZXhwb3J0IGNsYXNzIFBhc3N3b3JkTWFuYWdlcjxVSSBleHRlbmRzIFBhc3N3b3JkTWFuYWdlclVJPiB7XG4gIHdpbjogQmVhbVdpbmRvd1xuICBsb2dnZXI6IEJlYW1Mb2dnZXJcbiAgcGFzc3dvcmRIZWxwZXI6IFBhc3N3b3JkTWFuYWdlckhlbHBlclxuXG4gIC8qKlxuICAgKiBTaW5nbGV0b25cbiAgICpcbiAgICogQHR5cGUgUGFzc3dvcmRNYW5hZ2VyXG4gICAqL1xuICBzdGF0aWMgaW5zdGFuY2U6IFBhc3N3b3JkTWFuYWdlcjxhbnk+XG5cbiAgLyoqXG4gICAqIEBwYXJhbSB3aW4geyhCZWFtV2luZG93KX1cbiAgICogQHBhcmFtIHVpIHtQYXNzd29yZE1hbmFnZXJVSX1cbiAgICovXG4gIGNvbnN0cnVjdG9yKHdpbjogQmVhbVdpbmRvdzxhbnk+LCBwcm90ZWN0ZWQgdWk6IFVJKSB7XG4gICAgdGhpcy53aW4gPSB3aW5cbiAgICB0aGlzLmxvZ2dlciA9IG5ldyBCZWFtTG9nZ2VyKHdpbiwgQmVhbUxvZ0NhdGVnb3J5LndlYkF1dG9maWxsSW50ZXJuYWwpXG4gICAgdGhpcy5wYXNzd29yZEhlbHBlciA9IG5ldyBQYXNzd29yZE1hbmFnZXJIZWxwZXIod2luKVxuICAgIHRoaXMud2luLmFkZEV2ZW50TGlzdGVuZXIoXCJsb2FkXCIsIHRoaXMub25Mb2FkLmJpbmQodGhpcykpXG4gIH1cblxuICB0ZXh0RmllbGRzID0gW11cblxuICBvbkxvYWQoKTogdm9pZCB7XG4gICAgdGhpcy51aS5sb2FkKGRvY3VtZW50LlVSTClcbiAgfVxuXG4gIC8qKlxuICAgKiBJbnN0YWxscyB3aW5kb3cgcmVzaXplIGV2ZW50bGlzdGVuZXIgYW5kIGluc3RhbGxzIGZvY3VzXG4gICAqIGFuZCBmb2N1c291dCBldmVudGxpc3RlbmVycyBvbiBlYWNoIGVsZW1lbnQgZnJvbSB0aGUgcHJvdmlkZWQgaWRzXG4gICAqXG4gICAqIEBwYXJhbSB7c3RyaW5nfSBpZHNfanNvblxuICAgKiBAbWVtYmVyb2YgUGFzc3dvcmRNYW5hZ2VyXG4gICAqL1xuICBpbnN0YWxsRm9jdXNIYW5kbGVycyhpZHNfanNvbjogc3RyaW5nKTogdm9pZCB7XG4gICAgY29uc3QgaWRzID0gSlNPTi5wYXJzZShpZHNfanNvbilcbiAgICBmb3IgKGNvbnN0IGlkIG9mIGlkcykge1xuICAgICAgLy8gaW5zdGFsbCBoYW5kbGVycyB0byBhbGwgaW5wdXRzXG4gICAgICBjb25zdCBlbGVtZW50ID0gdGhpcy5wYXNzd29yZEhlbHBlci5nZXRFbGVtZW50QnlJZChpZClcbiAgICAgIGlmIChlbGVtZW50KSB7XG4gICAgICAgIGVsZW1lbnQuYWRkRXZlbnRMaXN0ZW5lcihcImZvY3VzXCIsIHRoaXMuZWxlbWVudERpZEdhaW5Gb2N1cy5iaW5kKHRoaXMpLCBmYWxzZSlcbiAgICAgICAgZWxlbWVudC5hZGRFdmVudExpc3RlbmVyKFwiZm9jdXNvdXRcIiwgdGhpcy5lbGVtZW50RGlkTG9zZUZvY3VzLmJpbmQodGhpcyksIGZhbHNlKVxuICAgICAgfVxuICAgIH1cblxuICAgIHRoaXMud2luLmFkZEV2ZW50TGlzdGVuZXIoXCJyZXNpemVcIiwgdGhpcy5yZXNpemUuYmluZCh0aGlzKSlcbiAgfVxuXG4gIHJlc2l6ZShldmVudDogQmVhbVVJRXZlbnQpOiB2b2lkIHtcbiAgICAvLyBlc2xpbnQtZGlzYWJsZS1uZXh0LWxpbmUgbm8tY29uc29sZVxuICAgIGNvbnNvbGUubG9nKFwicmVzaXplIVwiKVxuICAgIGlmIChldmVudC50YXJnZXQgIT09IG51bGwpIHtcbiAgICAgIHRoaXMudWkucmVzaXplKHRoaXMud2luLmlubmVyV2lkdGgsIHRoaXMud2luLmlubmVySGVpZ2h0KVxuICAgIH1cbiAgfVxuXG4gIGVsZW1lbnREaWRHYWluRm9jdXMoZXZlbnQ6IEJlYW1VSUV2ZW50KTogdm9pZCB7XG4gICAgaWYgKGV2ZW50LnRhcmdldCAhPT0gbnVsbCAmJiB0aGlzLnBhc3N3b3JkSGVscGVyLmlzVGV4dEZpZWxkKGV2ZW50LnRhcmdldCkpIHtcbiAgICAgIGNvbnN0IGJlYW1JZCA9IHRoaXMucGFzc3dvcmRIZWxwZXIuZ2V0T3JDcmVhdGVCZWFtSWQoZXZlbnQudGFyZ2V0KVxuICAgICAgY29uc3QgdGV4dCA9IGV2ZW50LnRhcmdldC52YWx1ZVxuICAgICAgdGhpcy51aS50ZXh0SW5wdXRSZWNlaXZlZEZvY3VzKGJlYW1JZCwgdGV4dClcbiAgICB9XG4gIH1cblxuICBlbGVtZW50RGlkTG9zZUZvY3VzKGV2ZW50OiBCZWFtVUlFdmVudCk6IHZvaWQge1xuICAgIGlmIChldmVudC50YXJnZXQgIT09IG51bGwgJiYgdGhpcy5wYXNzd29yZEhlbHBlci5pc1RleHRGaWVsZChldmVudC50YXJnZXQpKSB7XG4gICAgICBjb25zdCBiZWFtSWQgPSB0aGlzLnBhc3N3b3JkSGVscGVyLmdldE9yQ3JlYXRlQmVhbUlkKGV2ZW50LnRhcmdldClcbiAgICAgIHRoaXMudWkudGV4dElucHV0TG9zdEZvY3VzKGJlYW1JZClcbiAgICB9XG4gIH1cblxuICAvKipcbiAgICogSW5zdGFsbHMgZXZlbnRoYW5kbGVyIGZvciBzdWJtaXQgZXZlbnRzIG9uIGZvcm0gZWxlbWVudHNcbiAgICpcbiAgICogQG1lbWJlcm9mIFBhc3N3b3JkTWFuYWdlclxuICAgKi9cbiAgaW5zdGFsbFN1Ym1pdEhhbmRsZXIoKTogdm9pZCB7XG4gICAgY29uc3QgZm9ybXMgPSBkb2N1bWVudC5nZXRFbGVtZW50c0J5VGFnTmFtZShcImZvcm1cIilcbiAgICBmb3IgKGxldCBlID0gMDsgZSA8IGZvcm1zLmxlbmd0aDsgZSsrKSB7XG4gICAgICBjb25zdCBmb3JtID0gZm9ybXMuaXRlbShlKVxuICAgICAgZm9ybS5hZGRFdmVudExpc3RlbmVyKFwic3VibWl0XCIsIHRoaXMucG9zdFN1Ym1pdE1lc3NhZ2UuYmluZCh0aGlzKSlcbiAgICB9XG4gIH1cblxuICBwb3N0U3VibWl0TWVzc2FnZShldmVudCk6IHZvaWQge1xuICAgIGNvbnN0IGJlYW1JZCA9IHRoaXMucGFzc3dvcmRIZWxwZXIuZ2V0T3JDcmVhdGVCZWFtSWQoZXZlbnQudGFyZ2V0KVxuICAgIHRoaXMudWkuZm9ybVN1Ym1pdChiZWFtSWQpXG4gIH1cblxuICBzZW5kVGV4dEZpZWxkcyhmcmFtZUlkZW50aWZpZXIpIHtcblx0aWYgKGZyYW1lSWRlbnRpZmllciAhPT0gbnVsbCkge1xuICAgICAgdGhpcy5wYXNzd29yZEhlbHBlci5zZXRGcmFtZUlkZW50aWZpZXIoZnJhbWVJZGVudGlmaWVyKVxuICAgICAgdGhpcy5zZXR1cE9ic2VydmVyKClcblx0fVxuICAgIHRoaXMuaGFuZGxlVGV4dEZpZWxkcygpXG4gIH1cblxuICBzZXR1cE9ic2VydmVyKCkge1xuICAgIGNvbnN0IG9ic2VydmVyID0gbmV3IE11dGF0aW9uT2JzZXJ2ZXIodGhpcy5oYW5kbGVUZXh0RmllbGRzLmJpbmQodGhpcykpXG4gICAgb2JzZXJ2ZXIub2JzZXJ2ZShkb2N1bWVudCwgeyBjaGlsZExpc3Q6IHRydWUsIHN1YnRyZWU6IHRydWUgfSlcbiAgfVxuXG4gIGhhbmRsZVRleHRGaWVsZHMoKSB7XG4gICAgY29uc3QgdGV4dEZpZWxkcyA9IHRoaXMucGFzc3dvcmRIZWxwZXIuZ2V0VGV4dEZpZWxkc0luRG9jdW1lbnQoKVxuICAgIGlmICghaXNEZWVwRXF1YWwodGV4dEZpZWxkcywgdGhpcy50ZXh0RmllbGRzKSkge1xuICAgICAgdGhpcy50ZXh0RmllbGRzID0gdGV4dEZpZWxkc1xuICAgICAgY29uc3QgdGV4dEZpZWxkc1N0cmluZyA9IEpTT04uc3RyaW5naWZ5KHRleHRGaWVsZHMpXG4gICAgICB0aGlzLnVpLnNlbmRUZXh0RmllbGRzKHRleHRGaWVsZHNTdHJpbmcpXG4gICAgfVxuICB9XG5cbiAgdG9TdHJpbmcoKTogc3RyaW5nIHtcbiAgICByZXR1cm4gdGhpcy5jb25zdHJ1Y3Rvci5uYW1lXG4gIH1cbn1cbiIsImltcG9ydCB7QmVhbUhUTUxFbGVtZW50LCBCZWFtV2luZG93fSBmcm9tIFwiQGJlYW0vbmF0aXZlLWJlYW10eXBlc1wiXG5pbXBvcnQge0JlYW1FbGVtZW50SGVscGVyfSBmcm9tIFwiQGJlYW0vbmF0aXZlLXV0aWxzXCJcblxuZXhwb3J0IGNsYXNzIFBhc3N3b3JkTWFuYWdlckhlbHBlciB7XG4gIHdpbjogQmVhbVdpbmRvd1xuICBmcmFtZUlkZW50aWZpZXIgPSBcIlwiXG4gIGxhc3RJZCA9IDBcblxuXHQvKipcblx0ICogQHBhcmFtIHdpbiB7KEJlYW1XaW5kb3cpfVxuXHQgKi9cblx0Y29uc3RydWN0b3Iod2luOiBCZWFtV2luZG93PGFueT4pIHtcblx0ICB0aGlzLndpbiA9IHdpblxuXHR9XG5cbiAgLyoqXG4gICAqIFJldHVybnMgdHJ1ZSBpZiBlbGVtZW50IGlzIGEgdGV4dEZpZWxkIGVsZW1lbnRcbiAgICpcbiAgICogQHBhcmFtIHsqfSBlbGVtZW50XG4gICAqIEByZXR1cm4geyp9ICB7Ym9vbGVhbn1cbiAgICogQG1lbWJlcm9mIEhlbHBlcnNcbiAgICovXG4gIGlzVGV4dEZpZWxkKGVsZW1lbnQpOiBib29sZWFuIHtcbiAgICBpZiAoZWxlbWVudCA9PT0gbnVsbCkge1xuICAgICAgcmV0dXJuIGZhbHNlXG4gICAgfVxuICAgIGlmIChlbGVtZW50LmdldEF0dHJpYnV0ZShcImxpc3RcIikgIT09IG51bGwpIHtcbiAgICAgIHJldHVybiBmYWxzZVxuICAgIH1cbiAgICBjb25zdCBlbGVtZW50VHlwZSA9IGVsZW1lbnQuZ2V0QXR0cmlidXRlKFwidHlwZVwiKVxuICAgIHJldHVybiBlbGVtZW50VHlwZSA9PT0gXCJ0ZXh0XCIgfHwgZWxlbWVudFR5cGUgPT09IFwicGFzc3dvcmRcIiB8fCBlbGVtZW50VHlwZSA9PT0gXCJlbWFpbFwiIHx8IGVsZW1lbnRUeXBlID09PSBcIm51bWJlclwiIHx8IGVsZW1lbnRUeXBlID09PSBcInRlbFwiIHx8IGVsZW1lbnRUeXBlID09PSBcIlwiIHx8IGVsZW1lbnRUeXBlID09PSBudWxsXG4gIH1cblxuICAvKipcbiAgICogUmV0dXJucyB0cnVlIGlmIGVsZW1lbnQgaGFzIG5vIFwiZGlzYWJsZWRcIiBhdHRyaWJ1dGVcbiAgICpcbiAgICogQHBhcmFtIHsqfSBlbGVtZW50XG4gICAqIEByZXR1cm4geyp9ICB7Ym9vbGVhbn1cbiAgICogQG1lbWJlcm9mIEhlbHBlcnNcbiAgICovXG4gIGlzRW5hYmxlZChlbGVtZW50KTogYm9vbGVhbiB7XG4gICAgaWYgKGVsZW1lbnQgPT09IG51bGwpIHtcbiAgICAgIHJldHVybiBmYWxzZVxuICAgIH1cbiAgICBpZiAoXCJkaXNhYmxlZFwiIGluIGVsZW1lbnQuYXR0cmlidXRlcykge1xuICAgICAgcmV0dXJuICFlbGVtZW50LmRpc2FibGVkXG4gICAgfVxuICAgIHJldHVybiB0cnVlXG4gIH1cblxuICAvKipcbiAgICogUmV0dXJucyBuZXcgdW5pcXVlIGlkZW50aWZpZXIuIFRoZSBpZGVudGlmaWVyIGlzIHVuaXF1ZSB0byB0aGUgXG4gICAqIHdpbmRvdyBmcmFtZSBhbmQgZWFjaCB0aW1lIHRoaXMgbWV0aG9kIGlzIGNhbGxlZCB0aGUgdHJhaWxpbmcgXG4gICAqIG51bWJlciBpcyBpbmNyZW1lbnRlZC5cbiAgICpcbiAgICogQHJldHVybiB7Kn0gIHtzdHJpbmd9XG4gICAqIEBtZW1iZXJvZiBIZWxwZXJzXG4gICAqL1xuICBtYWtlQmVhbUlkKCk6IHN0cmluZyB7XG4gICAgdGhpcy5sYXN0SWQrK1xuICAgIHJldHVybiBcImJlYW0tXCIgKyB0aGlzLmZyYW1lSWRlbnRpZmllciArIFwiLVwiICsgdGhpcy5sYXN0SWRcbiAgfVxuXG4gIC8qKlxuICAgKiByZXR1cm5zIHRydWUgaWYgcHJvdmlkZWQgZWxlbWVudCBoYXMgYSBcImRhdGEtYmVhbS1pZFwiIGluIFxuICAgKiBpdCdzIGF0dHJpYnV0ZXMuXG4gICAqXG4gICAqIEBwYXJhbSB7Kn0gZWxlbWVudFxuICAgKiBAcmV0dXJuIHsqfSAge2Jvb2xlYW59XG4gICAqIEBtZW1iZXJvZiBIZWxwZXJzXG4gICAqL1xuICBoYXNCZWFtSWQoZWxlbWVudCk6IGJvb2xlYW4ge1xuICAgIHJldHVybiBcImRhdGEtYmVhbS1pZFwiIGluIGVsZW1lbnQuYXR0cmlidXRlc1xuICB9XG5cbiAgLyoqXG4gICAqIFJldHVybnMgdGhlIGJlYW0gSUQgb2YgdGhlIGVsZW1lbnQuIElmIG5vIElEIGlzIGZvdW5kIG9mIHRoZSBlbGVtZW50XG4gICAqIGEgdW5pcXVlIElEIHdpbGwgYmUgY3JlYXRlZCBhbmQgYXNzaWduZWQgdG8gdGhlIGVsZW1lbnQgYXR0cmlidXRlLlxuICAgKlxuICAgKiBAcGFyYW0geyp9IGVsZW1lbnRcbiAgICogQHJldHVybiB7Kn0gIHtzdHJpbmd9XG4gICAqIEBtZW1iZXJvZiBIZWxwZXJzXG4gICAqL1xuICBnZXRPckNyZWF0ZUJlYW1JZChlbGVtZW50KTogc3RyaW5nIHtcbiAgICBpZiAodGhpcy5oYXNCZWFtSWQoZWxlbWVudCkpIHtcbiAgICAgIHJldHVybiBlbGVtZW50LmRhdGFzZXQuYmVhbUlkXG4gICAgfVxuICAgIGNvbnN0IGJlYW1JZCA9IHRoaXMubWFrZUJlYW1JZCgpXG4gICAgZWxlbWVudC5kYXRhc2V0LmJlYW1JZCA9IGJlYW1JZFxuICAgIHJldHVybiBiZWFtSWRcbiAgfVxuXG4gIC8qKlxuICAgKiBGaW5kcyBhbmQgcmV0dXJucyBlbGVtZW50IGJhc2VkIG9uIHRoZSBiZWFtIElEXG4gICAqXG4gICAqIEBwYXJhbSB7c3RyaW5nfSBiZWFtSWRcbiAgICogQHJldHVybiB7Kn0gIHt9XG4gICAqIEBtZW1iZXJvZiBIZWxwZXJzXG4gICAqL1xuICBnZXRFbGVtZW50QnlJZChiZWFtSWQ6IHN0cmluZykge1xuICAgIHJldHVybiBkb2N1bWVudC5xdWVyeVNlbGVjdG9yKFwiW2RhdGEtYmVhbS1pZD0nXCIgKyBiZWFtSWQgKyBcIiddXCIpXG4gIH1cblxuICAvKipcbiAgICogRmluZHMgYW5kIHJldHVybnMgYWxsIG5vbi1kaXNhYmxlZCB0ZXh0IGZpZWxkIGVsZW1lbnRzIGluIHRoZSBkb2N1bWVudFxuICAgKlxuICAgKiBAcmV0dXJuIHsqfSAge0VsZW1lbnRbXX1cbiAgICogQG1lbWJlcm9mIEhlbHBlcnNcbiAgICovXG4gIGdldFRleHRGaWVsZHNJbkRvY3VtZW50KCk6IEVsZW1lbnRbXSB7XG4gICAgY29uc3QgdGV4dEZpZWxkcyA9IFtdXG4gICAgZm9yIChjb25zdCB0YWdOYW1lIG9mIFtcImlucHV0XCIsIFwic2VsZWN0XCIsIFwidGV4dGFyZWFcIl0pIHtcbiAgICAgIGNvbnN0IGlucHV0RWxlbWVudHMgPSB0aGlzLndpbi5kb2N1bWVudC5xdWVyeVNlbGVjdG9yQWxsKHRhZ05hbWUpIGFzIEJlYW1IVE1MRWxlbWVudFtdXG4gICAgICBmb3IgKGNvbnN0IGVsZW1lbnQgb2YgaW5wdXRFbGVtZW50cykge1xuICAgICAgICBpZiAodGhpcy5pc1RleHRGaWVsZChlbGVtZW50KSAmJiB0aGlzLmlzRW5hYmxlZChlbGVtZW50KSkge1xuICAgICAgICAgIHRoaXMuZ2V0T3JDcmVhdGVCZWFtSWQoZWxlbWVudClcbiAgICAgICAgICBjb25zdCBhdHRyaWJ1dGVzID0gZWxlbWVudC5hdHRyaWJ1dGVzXG4gICAgICAgICAgY29uc3QgdGV4dEZpZWxkID0ge3RhZ05hbWU6IGVsZW1lbnQudGFnTmFtZX1cbiAgICAgICAgICBmb3IgKGxldCBhID0gMDsgYSA8IGF0dHJpYnV0ZXMubGVuZ3RoOyBhKyspIHtcbiAgICAgICAgICAgIGNvbnN0IGF0dHIgPSBhdHRyaWJ1dGVzLml0ZW0oYSlcbiAgICAgICAgICAgIHRleHRGaWVsZFthdHRyLm5hbWVdID0gYXR0ci52YWx1ZVxuICAgICAgICAgIH1cbiAgICAgICAgICB0ZXh0RmllbGRbXCJ2aXNpYmxlXCJdID0gQmVhbUVsZW1lbnRIZWxwZXIuaXNWaXNpYmxlKGVsZW1lbnQsIHRoaXMud2luKVxuICAgICAgICAgIHRleHRGaWVsZHMucHVzaCh0ZXh0RmllbGQpXG4gICAgICAgIH1cbiAgICAgIH1cbiAgICB9XG4gICAgcmV0dXJuIHRleHRGaWVsZHNcbiAgfVxuXG4gIGdldEZvY3VzZWRGaWVsZCgpIHtcbiAgICByZXR1cm4gZG9jdW1lbnQuYWN0aXZlRWxlbWVudD8uZ2V0QXR0cmlidXRlKFwiZGF0YS1iZWFtLWlkXCIpXG4gIH1cblxuICBnZXRFbGVtZW50UmVjdHMoaWRzX2pzb24pIHtcbiAgICBjb25zdCBpZHMgPSBKU09OLnBhcnNlKGlkc19qc29uKVxuICAgIGNvbnN0IHJlY3RzID0gaWRzLm1hcChpZCA9PiB0aGlzLmdldEVsZW1lbnRCeUlkKGlkKT8uZ2V0Qm91bmRpbmdDbGllbnRSZWN0KCkpXG4gICAgcmV0dXJuIEpTT04uc3RyaW5naWZ5KHJlY3RzKVxuICB9XG5cbiAgZ2V0VGV4dEZpZWxkVmFsdWVzKGlkc19qc29uKSB7XG4gICAgY29uc3QgaWRzID0gSlNPTi5wYXJzZShpZHNfanNvbilcbiAgICBjb25zdCB2YWx1ZXMgPSBpZHMubWFwKGlkID0+IHtcbiAgICAgIGNvbnN0IGVsZW1lbnQgPSB0aGlzLmdldEVsZW1lbnRCeUlkKGlkKSBhcyBIVE1MSW5wdXRFbGVtZW50XG4gICAgICByZXR1cm4gZWxlbWVudC52YWx1ZVxuICAgIH0pXG4gICAgcmV0dXJuIEpTT04uc3RyaW5naWZ5KHZhbHVlcylcbiAgfVxuXG4gIHNldFRleHRGaWVsZFZhbHVlcyhmaWVsZHNfanNvbikge1xuICAgIGNvbnN0IGZpZWxkcyA9IEpTT04ucGFyc2UoZmllbGRzX2pzb24pXG4gICAgZm9yIChjb25zdCBmaWVsZCBvZiBmaWVsZHMpIHtcbiAgICAgIGNvbnN0IGVsZW1lbnQgPSB0aGlzLmdldEVsZW1lbnRCeUlkKGZpZWxkLmlkKVxuICAgICAgaWYgKGVsZW1lbnQ/LnRhZ05hbWUgPT0gXCJJTlBVVFwiKSB7XG4gICAgICAgIGNvbnN0IG5hdGl2ZUlucHV0VmFsdWVTZXR0ZXIgPSBPYmplY3QuZ2V0T3duUHJvcGVydHlEZXNjcmlwdG9yKHdpbmRvdy5IVE1MSW5wdXRFbGVtZW50LnByb3RvdHlwZSwgXCJ2YWx1ZVwiKS5zZXRcbiAgICAgICAgbmF0aXZlSW5wdXRWYWx1ZVNldHRlci5jYWxsKGVsZW1lbnQsIGZpZWxkLnZhbHVlKVxuICAgICAgICBjb25zdCBldmVudCA9IG5ldyBFdmVudChcImlucHV0XCIsIHsgYnViYmxlczogdHJ1ZSB9KVxuICAgICAgICAvLyBUT0RPOiBGaXggdGhpcyBcInNpbXVsYXRlZFwiIHZhbHVlXG4gICAgICAgIC8vIGV2ZW50LnNpbXVsYXRlZCA9IHRydWVcbiAgICAgICAgZWxlbWVudC5kaXNwYXRjaEV2ZW50KGV2ZW50KVxuICAgICAgICBpZiAoZmllbGQuYmFja2dyb3VuZCkge1xuICAgICAgICAgIGNvbnN0IHN0eWxlQXR0cmlidXRlID0gZG9jdW1lbnQuY3JlYXRlQXR0cmlidXRlKFwic3R5bGVcIilcbiAgICAgICAgICBzdHlsZUF0dHJpYnV0ZS52YWx1ZSA9IFwiYmFja2dyb3VuZC1jb2xvcjpcIiArIGZpZWxkLmJhY2tncm91bmRcbiAgICAgICAgICBlbGVtZW50LnNldEF0dHJpYnV0ZU5vZGUoc3R5bGVBdHRyaWJ1dGUpXG4gICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgY29uc3Qgc3R5bGVBdHRyaWJ1dGUgPSBlbGVtZW50LmdldEF0dHJpYnV0ZU5vZGUoXCJzdHlsZVwiKVxuICAgICAgICAgIGlmIChzdHlsZUF0dHJpYnV0ZSkge1xuICAgICAgICAgICAgZWxlbWVudC5yZW1vdmVBdHRyaWJ1dGVOb2RlKHN0eWxlQXR0cmlidXRlKVxuICAgICAgICAgIH1cbiAgICAgICAgfVxuICAgICAgfVxuICAgIH1cbiAgfVxuXG4gIHRvZ2dsZVBhc3N3b3JkRmllbGRWaXNpYmlsaXR5KGZpZWxkc19qc29uLCB2aXNpYmlsaXR5KSB7XG4gICAgY29uc3QgZmllbGRzID0gSlNPTi5wYXJzZShmaWVsZHNfanNvbilcbiAgICBmb3IgKGNvbnN0IGZpZWxkIG9mIGZpZWxkcykge1xuICAgICAgY29uc3QgcGFzc3dvcmRFbGVtZW50ID0gdGhpcy5nZXRFbGVtZW50QnlJZChmaWVsZC5pZClcbiAgICAgIGNvbnN0IGVsZW1lbnRUeXBlID0gcGFzc3dvcmRFbGVtZW50LmdldEF0dHJpYnV0ZShcInR5cGVcIilcbiAgICAgIGlmIChlbGVtZW50VHlwZSA9PT0gXCJwYXNzd29yZFwiICYmICh2aXNpYmlsaXR5ID09IFwidHJ1ZVwiKSkge1xuICAgICAgICBwYXNzd29yZEVsZW1lbnQuc2V0QXR0cmlidXRlKFwidHlwZVwiLCBcInRleHRcIilcbiAgICAgIH1cbiAgICAgIGlmIChlbGVtZW50VHlwZSA9PT0gXCJ0ZXh0XCIgJiYgKHZpc2liaWxpdHkgPT0gXCJmYWxzZVwiKSkge1xuICAgICAgICBwYXNzd29yZEVsZW1lbnQuc2V0QXR0cmlidXRlKFwidHlwZVwiLCBcInBhc3N3b3JkXCIpXG4gICAgICB9XG4gICAgfVxuICB9XG5cbiAgc2V0RnJhbWVJZGVudGlmaWVyKGZyYW1lSWRlbnRpZmllcjogc3RyaW5nKTogdm9pZCB7XG4gICAgdGhpcy5mcmFtZUlkZW50aWZpZXIgPSBmcmFtZUlkZW50aWZpZXJcbiAgfVxufVxuIiwiaW1wb3J0IHtcbiAgQmVhbUxvZ0NhdGVnb3J5LFxuICBCZWFtV2luZG93LFxuICBOYXRpdmVcbn0gZnJvbSBcIkBiZWFtL25hdGl2ZS1iZWFtdHlwZXNcIlxuaW1wb3J0IHsgQmVhbUxvZ2dlciB9IGZyb20gXCJAYmVhbS9uYXRpdmUtdXRpbHNcIlxuaW1wb3J0IHsgUGFzc3dvcmRNYW5hZ2VyVUkgfSBmcm9tIFwiLi9QYXNzd29yZE1hbmFnZXJVSVwiXG5cbmV4cG9ydCBjbGFzcyBQYXNzd29yZE1hbmFnZXJVSV9uYXRpdmUgaW1wbGVtZW50cyBQYXNzd29yZE1hbmFnZXJVSSB7XG4gIGxvZ2dlcjogQmVhbUxvZ2dlclxuICAvKipcbiAgICogQHBhcmFtIG5hdGl2ZSB7TmF0aXZlfVxuICAgKi9cbiAgY29uc3RydWN0b3IocHJvdGVjdGVkIG5hdGl2ZTogTmF0aXZlPGFueT4pIHtcbiAgICB0aGlzLmxvZ2dlciA9IG5ldyBCZWFtTG9nZ2VyKHRoaXMubmF0aXZlLndpbiwgQmVhbUxvZ0NhdGVnb3J5LndlYkF1dG9maWxsSW50ZXJuYWwpXG4gIH1cblxuICAvKipcbiAgICpcbiAgICogQHBhcmFtIHdpbiB7QmVhbVdpbmRvd31cbiAgICogQHJldHVybnMge1Bhc3N3b3JkTWFuYWdlclVJX25hdGl2ZX1cbiAgICovXG4gIHN0YXRpYyBnZXRJbnN0YW5jZSh3aW46IEJlYW1XaW5kb3cpOiBQYXNzd29yZE1hbmFnZXJVSV9uYXRpdmUge1xuICAgIGxldCBpbnN0YW5jZVxuICAgIHRyeSB7XG4gICAgICBjb25zdCBuYXRpdmUgPSBOYXRpdmUuZ2V0SW5zdGFuY2Uod2luLCBcIlBhc3N3b3JkTWFuYWdlclwiKVxuICAgICAgaW5zdGFuY2UgPSBuZXcgUGFzc3dvcmRNYW5hZ2VyVUlfbmF0aXZlKG5hdGl2ZSlcbiAgICB9IGNhdGNoIChlKSB7XG4gICAgICAvLyBlc2xpbnQtZGlzYWJsZS1uZXh0LWxpbmUgbm8tY29uc29sZVxuICAgICAgY29uc29sZS5lcnJvcihlKVxuICAgICAgaW5zdGFuY2UgPSBudWxsXG4gICAgfVxuICAgIHJldHVybiBpbnN0YW5jZVxuICB9XG5cbiAgbG9hZCh1cmw6IHN0cmluZykge1xuICAgICAgdGhpcy5uYXRpdmUuc2VuZE1lc3NhZ2UoXCJsb2FkZWRcIiwgeyB1cmwgfSlcbiAgfVxuXG4gIHJlc2l6ZSh3aWR0aDogbnVtYmVyLCBoZWlnaHQ6IG51bWJlcikge1xuICAgIHRoaXMubmF0aXZlLnNlbmRNZXNzYWdlKFwicmVzaXplXCIsIHsgd2lkdGgsIGhlaWdodCB9KVxuICB9XG5cbiAgdGV4dElucHV0UmVjZWl2ZWRGb2N1cyhpZDogc3RyaW5nLCB0ZXh0OiBzdHJpbmcpOiB2b2lkIHtcbiAgICB0aGlzLm5hdGl2ZS5zZW5kTWVzc2FnZShcInRleHRJbnB1dEZvY3VzSW5cIiwgeyBpZCwgdGV4dCB9KVxuICB9XG5cbiAgdGV4dElucHV0TG9zdEZvY3VzKGlkOiBzdHJpbmcpOiB2b2lkIHtcbiAgICB0aGlzLm5hdGl2ZS5zZW5kTWVzc2FnZShcInRleHRJbnB1dEZvY3VzT3V0XCIsIHsgaWQgfSlcbiAgfVxuXG4gIGZvcm1TdWJtaXQoaWQ6IHN0cmluZyk6IHZvaWQge1xuICAgIHRoaXMubmF0aXZlLnNlbmRNZXNzYWdlKFwiZm9ybVN1Ym1pdFwiLCB7IGlkIH0pXG4gIH1cblxuICBzZW5kVGV4dEZpZWxkcyh0ZXh0RmllbGRzU3RyaW5nOiBzdHJpbmcpOiB2b2lkIHtcbiAgICAgIHRoaXMubmF0aXZlLnNlbmRNZXNzYWdlKFwidGV4dElucHV0RmllbGRzXCIsIHt0ZXh0RmllbGRzU3RyaW5nfSlcbiAgfVxuXG4gIHRvU3RyaW5nKCk6IHN0cmluZyB7XG4gICAgcmV0dXJuIHRoaXMuY29uc3RydWN0b3IubmFtZVxuICB9XG59XG4iLCIvLyBUaGUgbW9kdWxlIGNhY2hlXG52YXIgX193ZWJwYWNrX21vZHVsZV9jYWNoZV9fID0ge307XG5cbi8vIFRoZSByZXF1aXJlIGZ1bmN0aW9uXG5mdW5jdGlvbiBfX3dlYnBhY2tfcmVxdWlyZV9fKG1vZHVsZUlkKSB7XG5cdC8vIENoZWNrIGlmIG1vZHVsZSBpcyBpbiBjYWNoZVxuXHR2YXIgY2FjaGVkTW9kdWxlID0gX193ZWJwYWNrX21vZHVsZV9jYWNoZV9fW21vZHVsZUlkXTtcblx0aWYgKGNhY2hlZE1vZHVsZSAhPT0gdW5kZWZpbmVkKSB7XG5cdFx0cmV0dXJuIGNhY2hlZE1vZHVsZS5leHBvcnRzO1xuXHR9XG5cdC8vIENyZWF0ZSBhIG5ldyBtb2R1bGUgKGFuZCBwdXQgaXQgaW50byB0aGUgY2FjaGUpXG5cdHZhciBtb2R1bGUgPSBfX3dlYnBhY2tfbW9kdWxlX2NhY2hlX19bbW9kdWxlSWRdID0ge1xuXHRcdC8vIG5vIG1vZHVsZS5pZCBuZWVkZWRcblx0XHQvLyBubyBtb2R1bGUubG9hZGVkIG5lZWRlZFxuXHRcdGV4cG9ydHM6IHt9XG5cdH07XG5cblx0Ly8gRXhlY3V0ZSB0aGUgbW9kdWxlIGZ1bmN0aW9uXG5cdF9fd2VicGFja19tb2R1bGVzX19bbW9kdWxlSWRdLmNhbGwobW9kdWxlLmV4cG9ydHMsIG1vZHVsZSwgbW9kdWxlLmV4cG9ydHMsIF9fd2VicGFja19yZXF1aXJlX18pO1xuXG5cdC8vIFJldHVybiB0aGUgZXhwb3J0cyBvZiB0aGUgbW9kdWxlXG5cdHJldHVybiBtb2R1bGUuZXhwb3J0cztcbn1cblxuIiwiLy8gZ2V0RGVmYXVsdEV4cG9ydCBmdW5jdGlvbiBmb3IgY29tcGF0aWJpbGl0eSB3aXRoIG5vbi1oYXJtb255IG1vZHVsZXNcbl9fd2VicGFja19yZXF1aXJlX18ubiA9IChtb2R1bGUpID0+IHtcblx0dmFyIGdldHRlciA9IG1vZHVsZSAmJiBtb2R1bGUuX19lc01vZHVsZSA/XG5cdFx0KCkgPT4gKG1vZHVsZVsnZGVmYXVsdCddKSA6XG5cdFx0KCkgPT4gKG1vZHVsZSk7XG5cdF9fd2VicGFja19yZXF1aXJlX18uZChnZXR0ZXIsIHsgYTogZ2V0dGVyIH0pO1xuXHRyZXR1cm4gZ2V0dGVyO1xufTsiLCIvLyBkZWZpbmUgZ2V0dGVyIGZ1bmN0aW9ucyBmb3IgaGFybW9ueSBleHBvcnRzXG5fX3dlYnBhY2tfcmVxdWlyZV9fLmQgPSAoZXhwb3J0cywgZGVmaW5pdGlvbikgPT4ge1xuXHRmb3IodmFyIGtleSBpbiBkZWZpbml0aW9uKSB7XG5cdFx0aWYoX193ZWJwYWNrX3JlcXVpcmVfXy5vKGRlZmluaXRpb24sIGtleSkgJiYgIV9fd2VicGFja19yZXF1aXJlX18ubyhleHBvcnRzLCBrZXkpKSB7XG5cdFx0XHRPYmplY3QuZGVmaW5lUHJvcGVydHkoZXhwb3J0cywga2V5LCB7IGVudW1lcmFibGU6IHRydWUsIGdldDogZGVmaW5pdGlvbltrZXldIH0pO1xuXHRcdH1cblx0fVxufTsiLCJfX3dlYnBhY2tfcmVxdWlyZV9fLm8gPSAob2JqLCBwcm9wKSA9PiAoT2JqZWN0LnByb3RvdHlwZS5oYXNPd25Qcm9wZXJ0eS5jYWxsKG9iaiwgcHJvcCkpIiwiLy8gZGVmaW5lIF9fZXNNb2R1bGUgb24gZXhwb3J0c1xuX193ZWJwYWNrX3JlcXVpcmVfXy5yID0gKGV4cG9ydHMpID0+IHtcblx0aWYodHlwZW9mIFN5bWJvbCAhPT0gJ3VuZGVmaW5lZCcgJiYgU3ltYm9sLnRvU3RyaW5nVGFnKSB7XG5cdFx0T2JqZWN0LmRlZmluZVByb3BlcnR5KGV4cG9ydHMsIFN5bWJvbC50b1N0cmluZ1RhZywgeyB2YWx1ZTogJ01vZHVsZScgfSk7XG5cdH1cblx0T2JqZWN0LmRlZmluZVByb3BlcnR5KGV4cG9ydHMsICdfX2VzTW9kdWxlJywgeyB2YWx1ZTogdHJ1ZSB9KTtcbn07IiwiaW1wb3J0IHsgTmF0aXZlIH0gZnJvbSBcIkBiZWFtL25hdGl2ZS1iZWFtdHlwZXNcIlxuaW1wb3J0IHtQYXNzd29yZE1hbmFnZXJ9IGZyb20gXCIuL1Bhc3N3b3JkTWFuYWdlclwiXG5pbXBvcnQge1Bhc3N3b3JkTWFuYWdlclVJX25hdGl2ZX0gZnJvbSBcIi4vUGFzc3dvcmRNYW5hZ2VyVUlfbmF0aXZlXCJcblxuY29uc3QgbmF0aXZlID0gTmF0aXZlLmdldEluc3RhbmNlKHdpbmRvdywgXCJQYXNzd29yZE1hbmFnZXJcIilcbmNvbnN0IFBhc3N3b3JkTWFuYWdlclVJID0gbmV3IFBhc3N3b3JkTWFuYWdlclVJX25hdGl2ZShuYXRpdmUpXG5cbmlmICghd2luZG93LmJlYW0pIHtcbiAgd2luZG93LmJlYW0gPSB7fVxufVxuXG53aW5kb3cuYmVhbS5fX0lEX19QYXNzd29yZE1hbmFnZXIgPSBuZXcgUGFzc3dvcmRNYW5hZ2VyKHdpbmRvdywgUGFzc3dvcmRNYW5hZ2VyVUkpXG4iXSwibmFtZXMiOltdLCJzb3VyY2VSb290IjoiIn0=