"use strict";
/*
 * Types used by Beam API (to exchange messages, typically).
 */
Object.defineProperty(exports, "__esModule", { value: true });
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
//# sourceMappingURL=BeamTypes.js.map