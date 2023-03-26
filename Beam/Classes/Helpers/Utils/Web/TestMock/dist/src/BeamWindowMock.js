"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BeamWindowMock = exports.BeamCryptoMock = exports.BeamVisualViewportMock = exports.MessageHandlerMock = void 0;
const BeamEventTargetMock_1 = require("./BeamEventTargetMock");
const BeamLocationMock_1 = require("./BeamLocationMock");
const BeamDocumentMock_1 = require("./BeamDocumentMock");
class MessageHandlerMock {
    constructor() {
        this.events = [];
    }
    postMessage(payload) {
        this.events.push({ name: "postMessage", payload });
    }
}
exports.MessageHandlerMock = MessageHandlerMock;
class BeamVisualViewportMock extends BeamEventTargetMock_1.BeamEventTargetMock {
}
exports.BeamVisualViewportMock = BeamVisualViewportMock;
class BeamCryptoMock {
    getRandomValues(buffer) {
        // Really basic mock for getting random numbers
        return buffer.map(item => {
            return Math.floor(Math.random() * 9999999);
        });
    }
}
exports.BeamCryptoMock = BeamCryptoMock;
class BeamWindowMock extends BeamEventTargetMock_1.BeamEventTargetMock {
    constructor(doc = new BeamDocumentMock_1.BeamDocumentMock(), location = new BeamLocationMock_1.BeamLocationMock()) {
        super();
        this.visualViewport = new BeamVisualViewportMock();
        this.crypto = new BeamCryptoMock();
        this.scrollX = 0;
        this.scrollY = 0;
        this.document = doc;
        this.location = location;
        this.visualViewport.scale = 1;
    }
    scrollTo(xCoord, yCoord) {
        throw new Error("Method not implemented.");
    }
    matchMedia(arg0) { }
    scroll(xCoord, yCoord) {
        this.scrollX = xCoord;
        this.scrollY = yCoord;
    }
    getEventListeners(_win) {
        return this.eventListeners;
    }
    getComputedStyle(el, pseudo) {
        if (pseudo) {
            throw new Error("getComputedStyle not implemented for pseudo elements");
        }
        return el.style;
    }
    open(url, name, specs, replace) {
        console.log(`opening ${url}`);
        return this.create(new BeamDocumentMock_1.BeamDocumentMock(), new BeamLocationMock_1.BeamLocationMock({ href: url }));
    }
}
exports.BeamWindowMock = BeamWindowMock;
//# sourceMappingURL=BeamWindowMock.js.map