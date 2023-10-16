"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BeamResizeObserverMock = exports.BeamMutationObserverMock = void 0;
class BeamMutationObserverMock {
    constructor(fn) {
        this.fn = fn;
        this.targets = [];
        console.log("BeamMutationObserverMock init");
    }
    disconnect() {
        this.targets = [];
    }
    observe(target, options) {
        this.targets.push(target);
    }
    takeRecords() {
        throw new Error("Method not implemented.");
    }
}
exports.BeamMutationObserverMock = BeamMutationObserverMock;
class BeamResizeObserverMock {
    constructor(fn) {
        this.fn = fn;
    }
    observe() {
        // throw new Error("Method not implemented.")
    }
    unobserve() {
        // throw new Error("Method not implemented.")
    }
    disconnect() {
        // throw new Error("Method not implemented.")
    }
}
exports.BeamResizeObserverMock = BeamResizeObserverMock;
//# sourceMappingURL=BeamWebFactoryMock.js.map