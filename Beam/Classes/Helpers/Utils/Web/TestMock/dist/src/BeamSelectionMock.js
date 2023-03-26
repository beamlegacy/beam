"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BeamSelectionMock = void 0;
const BeamElementMock_1 = require("./BeamElementMock");
class BeamSelectionMock {
    constructor(nodeName, attributes = {}) {
        this.rangeCount = 0;
        this.rangelist = [];
        this.anchorNode = new BeamElementMock_1.BeamElementMock(nodeName);
        this.focusNode = new BeamElementMock_1.BeamElementMock(nodeName);
    }
    addRange(range) {
        this.anchorNode = range.startContainer;
        this.focusNode = range.endContainer;
        this.rangelist.push(range);
        this.rangeCount++;
    }
    collapse(node, offset) {
        throw new Error("Method not implemented.");
    }
    collapseToEnd() {
        throw new Error("Method not implemented.");
    }
    collapseToStart() {
        throw new Error("Method not implemented.");
    }
    containsNode(node, allowPartialContainment) {
        throw new Error("Method not implemented.");
    }
    deleteFromDocument() {
        throw new Error("Method not implemented.");
    }
    empty() {
        throw new Error("Method not implemented.");
    }
    extend(node, offset) {
        throw new Error("Method not implemented.");
    }
    getRangeAt(index) {
        return this.rangelist[index];
    }
    removeAllRanges() {
        throw new Error("Method not implemented.");
    }
    removeRange(range) {
        throw new Error("Method not implemented.");
    }
    selectAllChildren(node) {
        throw new Error("Method not implemented.");
    }
    setBaseAndExtent(anchorNode, anchorOffset, focusNode, focusOffset) {
        throw new Error("Method not implemented.");
    }
    setPosition(node, offset) {
        throw new Error("Method not implemented.");
    }
    toString() {
        return "";
    }
}
exports.BeamSelectionMock = BeamSelectionMock;
//# sourceMappingURL=BeamSelectionMock.js.map