import { BeamRect } from "@beam/native-beamtypes";
export declare class BeamRectHelper {
    static filterRectArrayByRectArray(sourceArray: BeamRect[], filterArray: BeamRect[]): BeamRect[];
    static doRectMatchesRectsInArray(sourceRect: BeamRect, filterArray: BeamRect[]): boolean;
    static doRectsMatch(rect1: BeamRect, rect2: BeamRect): boolean;
    /**
     * Return the bounding rectangle for two given rectangles
     *
     * @param rect1
     * @param rect2
     */
    static boundingRect(rect1: BeamRect, rect2: BeamRect): BeamRect;
    /**
     * Get the intersection of two given rectangles, the rectangles can have infinite dimensions
     * (for instance when `x` and `width` properties are respectively -Infinity and Infinity)
     *
     * @param rect1
     * @param rect2
     * @return {BeamRect} if the intersection is defined
     * @return undefined when no intersection exist
     */
    static intersection(rect1: BeamRect, rect2: BeamRect): BeamRect;
}
