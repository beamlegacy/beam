import { BeamDOMRect } from "@beam/native-beamtypes";
export declare class BeamDOMRectMock implements BeamDOMRect {
    x: number;
    y: number;
    width: number;
    height: number;
    top: number;
    left: number;
    right: number;
    bottom: number;
    constructor(x: number, y: number, width: number, height: number);
    toJSON(): any;
}
