"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BeamDOMRectMock = void 0;
class BeamDOMRectMock {
    constructor(x, y, width, height) {
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
        this.top = y;
        this.left = x;
        this.right = x + width;
        this.bottom = y + height;
    }
    toJSON() {
        return JSON.stringify(this);
    }
}
exports.BeamDOMRectMock = BeamDOMRectMock;
//# sourceMappingURL=BeamDOMRectMock.js.map