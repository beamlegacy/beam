"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BeamLocationMock = void 0;
class BeamLocationMock {
    constructor(attributes = {}) {
        Object.assign(this, attributes);
    }
    toString() {
        throw new Error("Method not implemented.");
    }
    assign(url) {
        throw new Error("Method not implemented.");
    }
    reload(forcedReload) {
        throw new Error("Method not implemented.");
    }
    replace(url) {
        throw new Error("Method not implemented.");
    }
}
exports.BeamLocationMock = BeamLocationMock;
//# sourceMappingURL=BeamLocationMock.js.map