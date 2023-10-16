"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BeamRectHelper = void 0;
class BeamRectHelper {
    static filterRectArrayByRectArray(sourceArray, filterArray) {
        return sourceArray.filter((sourceRect) => {
            // When rect matches array return true to filter it
            return this.doRectMatchesRectsInArray(sourceRect, filterArray) == false;
        });
    }
    static doRectMatchesRectsInArray(sourceRect, filterArray) {
        return filterArray.some((filterRect) => {
            return this.doRectsMatch(sourceRect, filterRect);
        });
    }
    static doRectsMatch(rect1, rect2) {
        return (Math.round(rect1 === null || rect1 === void 0 ? void 0 : rect1.x) == Math.round(rect2 === null || rect2 === void 0 ? void 0 : rect2.x) &&
            Math.round(rect1 === null || rect1 === void 0 ? void 0 : rect1.y) == Math.round(rect2 === null || rect2 === void 0 ? void 0 : rect2.y) &&
            Math.round(rect1 === null || rect1 === void 0 ? void 0 : rect1.height) == Math.round(rect2 === null || rect2 === void 0 ? void 0 : rect2.height) &&
            Math.round(rect1 === null || rect1 === void 0 ? void 0 : rect1.width) == Math.round(rect2 === null || rect2 === void 0 ? void 0 : rect2.width));
    }
    /**
     * Return the bounding rectangle for two given rectangles
     *
     * @param rect1
     * @param rect2
     */
    static boundingRect(rect1, rect2) {
        const x = Math.min(rect1.x, rect2.x);
        const y = Math.min(rect1.y, rect2.y);
        const width = Math.max(rect1.x + rect1.width, rect2.x + rect2.width) - x;
        const height = Math.max(rect1.y + rect1.height, rect2.y + rect2.height) - y;
        return { x, y, width, height };
    }
    /**
     * Get the intersection of two given rectangles, the rectangles can have infinite dimensions
     * (for instance when `x` and `width` properties are respectively -Infinity and Infinity)
     *
     * @param rect1
     * @param rect2
     * @return {BeamRect} if the intersection is defined
     * @return undefined when no intersection exist
     */
    static intersection(rect1, rect2) {
        const x = Math.max(rect1.x, rect2.x);
        const y = Math.max(rect1.y, rect2.y);
        // rects can have Infinite dimensions, in which case have to filter out NaN values
        // since -Infinity + Infinity is NaN (rect.x + rect.width or rect.y + rect.height)
        const validX2 = [rect1.x + rect1.width, rect2.x + rect2.width].filter(v => !isNaN(v));
        const x2 = Math.min(...validX2);
        const validY2 = [rect1.y + rect1.height, rect2.y + rect2.height].filter(v => !isNaN(v));
        const y2 = Math.min(...validY2);
        if (x2 > x && y2 > y) {
            return { x, y, width: x2 - x, height: y2 - y };
        }
    }
}
exports.BeamRectHelper = BeamRectHelper;
//# sourceMappingURL=BeamRectHelper.js.map