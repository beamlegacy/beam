"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BeamHTMLIFrameElementMock = void 0;
const native_beamtypes_1 = require("@beam/native-beamtypes");
const BeamHTMLElementMock_1 = require("./BeamHTMLElementMock");
class BeamHTMLIFrameElementMock extends BeamHTMLElementMock_1.BeamHTMLElementMock {
    constructor(contentWindow, attributes = new native_beamtypes_1.BeamNamedNodeMap()) {
        super("iframe", attributes);
        this.contentWindow = contentWindow;
    }
    focus() {
        throw new Error("Method not implemented.");
    }
    setAttribute(qualifiedName, value) {
        throw new Error("Method not implemented.");
    }
    getAttribute(qualifiedName) {
        throw new Error("Method not implemented.");
    }
    /**
     * @param delta {number} positive or negative scroll delta
     * @return the scroll event
     */
    scrollY(delta) {
        this.clientTop += delta;
        const win = this.contentWindow;
        win.scroll(0, win.scrollY + delta);
        const scrollEvent = new native_beamtypes_1.BeamUIEvent();
        Object.assign(scrollEvent, { name: "scroll" });
        return scrollEvent;
    }
}
exports.BeamHTMLIFrameElementMock = BeamHTMLIFrameElementMock;
//# sourceMappingURL=BeamHTMLIFrameElementMock.js.map