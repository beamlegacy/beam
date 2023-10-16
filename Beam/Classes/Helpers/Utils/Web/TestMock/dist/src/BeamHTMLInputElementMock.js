"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BeamHTMLInputElementMock = void 0;
const BeamHTMLElementMock_1 = require("./BeamHTMLElementMock");
class BeamHTMLInputElementMock extends BeamHTMLElementMock_1.BeamHTMLElementMock {
    focus() {
        throw new Error("Method not implemented.");
    }
    get type() {
        const attribute = this.attributes.getNamedItem("type");
        return attribute === null || attribute === void 0 ? void 0 : attribute.value;
    }
    set type(value) {
        this.attributes.getNamedItem("type").value = value;
    }
}
exports.BeamHTMLInputElementMock = BeamHTMLInputElementMock;
//# sourceMappingURL=BeamHTMLInputElementMock.js.map