"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BeamRangeMock = void 0;
const native_beamtypes_1 = require("@beam/native-beamtypes");
const BeamDOMRectMock_1 = require("./BeamDOMRectMock");
class BeamRangeMock {
    cloneRange() {
        throw new Error("Method not implemented.");
    }
    collapse(toStart) {
        throw new Error("Method not implemented.");
    }
    compareBoundaryPoints(how, sourceRange) {
        throw new Error("Method not implemented.");
    }
    comparePoint(node, offset) {
        throw new Error("Method not implemented.");
    }
    createContextualFragment(fragment) {
        throw new Error("Method not implemented.");
    }
    deleteContents() {
        throw new Error("Method not implemented.");
    }
    detach() {
        throw new Error("Method not implemented.");
    }
    extractContents() {
        throw new Error("Method not implemented.");
    }
    getClientRects() {
        const rect = new BeamDOMRectMock_1.BeamDOMRectMock(0, 0, 0, 0);
        return new native_beamtypes_1.BeamDOMRectList([rect]);
    }
    insertNode(node) {
        throw new Error("Method not implemented.");
    }
    intersectsNode(node) {
        throw new Error("Method not implemented.");
    }
    isPointInRange(node, offset) {
        throw new Error("Method not implemented.");
    }
    selectNodeContents(node) {
        throw new Error("Method not implemented.");
    }
    setEnd(node, offset) {
        this.endOffset = offset;
        this.endContainer = node;
    }
    setEndAfter(node) {
        throw new Error("Method not implemented.");
    }
    setEndBefore(node) {
        throw new Error("Method not implemented.");
    }
    setStart(node, offset) {
        this.startOffset = offset;
        this.startContainer = node;
    }
    setStartAfter(node) {
        throw new Error("Method not implemented.");
    }
    setStartBefore(node) {
        throw new Error("Method not implemented.");
    }
    surroundContents(newParent) {
        throw new Error("Method not implemented.");
    }
    toString() {
        return "mock range content";
    }
    cloneContents() {
        return this.startContainer;
    }
    getBoundingClientRect() {
        return Object.assign(Object.assign({}, this.node.bounds), { bottom: 0, left: 0, right: 0, top: 0, toJSON: () => "toJSON value not implemented" });
    }
    selectNode(node) {
        this.node = node;
        const parentBox = node.parentElement.getBoundingClientRect();
        this.node.bounds.x = this.node.bounds.x || parentBox.x;
        this.node.bounds.y = this.node.bounds.y || parentBox.y;
        this.node.bounds.width = this.node.bounds.width || parentBox.width;
        this.node.bounds.height = this.node.bounds.height || parentBox.height;
    }
}
exports.BeamRangeMock = BeamRangeMock;
//# sourceMappingURL=BeamRangeMock.js.map