"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.NativeMock = void 0;
const native_beamtypes_1 = require("@beam/native-beamtypes");
class NativeMock extends native_beamtypes_1.Native {
    constructor(win, componentPrefix) {
        super(win, componentPrefix);
        this.events = [];
    }
    sendMessage(name, payload) {
        this.events.push({ name: `sendMessage ${name}`, payload });
    }
}
exports.NativeMock = NativeMock;
//# sourceMappingURL=NativeMock.js.map