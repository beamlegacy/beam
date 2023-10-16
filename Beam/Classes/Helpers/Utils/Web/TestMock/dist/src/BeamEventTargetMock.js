"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BeamEventTargetMock = void 0;
class BeamEventTargetMock {
    constructor() {
        this.eventListeners = {};
    }
    addEventListener(type, callback) {
        if (!(type in this.eventListeners)) {
            this.eventListeners[type] = [];
        }
        this.eventListeners[type].push(callback);
    }
    removeEventListener(type, callback) {
        if (!(type in this.eventListeners)) {
            return;
        }
        const stack = this.eventListeners[type];
        for (let i = 0, l = stack.length; i < l; i++) {
            if (stack[i] === callback) {
                stack.splice(i, 1);
                return;
            }
        }
    }
    dispatchEvent(event) {
        if (!(event.type in this.eventListeners)) {
            return true;
        }
        const stack = this.eventListeners[event.type].slice();
        for (let i = 0, l = stack.length; i < l; i++) {
            stack[i].call(this, event);
        }
        return !event.defaultPrevented;
    }
}
exports.BeamEventTargetMock = BeamEventTargetMock;
//# sourceMappingURL=BeamEventTargetMock.js.map