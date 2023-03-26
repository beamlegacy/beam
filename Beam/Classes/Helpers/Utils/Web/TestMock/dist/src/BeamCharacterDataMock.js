"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BeamCharacterDataMock = void 0;
const BeamNodeMock_1 = require("./BeamNodeMock");
const native_beamtypes_1 = require("@beam/native-beamtypes");
class BeamCharacterDataMock extends BeamNodeMock_1.BeamNodeMock {
    constructor(data, props = {}) {
        super("#text", native_beamtypes_1.BeamNodeType.text, props);
        this.data = data;
    }
    get length() {
        return this.data.length;
    }
    toString() {
        return this.data;
    }
}
exports.BeamCharacterDataMock = BeamCharacterDataMock;
//# sourceMappingURL=BeamCharacterDataMock.js.map