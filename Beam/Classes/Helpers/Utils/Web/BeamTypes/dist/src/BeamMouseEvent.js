"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BeamMouseEvent = void 0;
const BeamUIEvent_1 = require("./BeamUIEvent");
class BeamMouseEvent extends BeamUIEvent_1.BeamUIEvent {
    constructor(attributes = {}) {
        super();
        Object.assign(this, attributes);
    }
}
exports.BeamMouseEvent = BeamMouseEvent;
//# sourceMappingURL=BeamMouseEvent.js.map