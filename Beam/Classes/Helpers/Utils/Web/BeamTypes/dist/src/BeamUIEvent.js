"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
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
//# sourceMappingURL=BeamUIEvent.js.map