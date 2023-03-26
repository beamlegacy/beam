"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BeamKeyEvent = void 0;
const BeamMouseEvent_1 = require("./BeamMouseEvent");
class BeamKeyEvent extends BeamMouseEvent_1.BeamMouseEvent {
    constructor(attributes = {}) {
        super();
        Object.assign(this, attributes);
    }
}
exports.BeamKeyEvent = BeamKeyEvent;
//# sourceMappingURL=BeamKeyEvent.js.map