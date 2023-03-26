"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BeamDOMRectList = void 0;
class BeamDOMRectList {
    constructor(list) {
        this.list = list;
    }
    get length() {
        return this.list.length;
    }
    [Symbol.iterator]() {
        return this.list.values();
    }
    item(index) {
        return this.list[index];
    }
}
exports.BeamDOMRectList = BeamDOMRectList;
//# sourceMappingURL=BeamDOMRectList.js.map