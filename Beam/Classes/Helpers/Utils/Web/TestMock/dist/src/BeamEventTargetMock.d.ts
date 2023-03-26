import { BeamEvent, BeamEventTarget } from "@beam/native-beamtypes";
export declare class BeamEventTargetMock implements BeamEventTarget {
    readonly eventListeners: {};
    addEventListener(type: any, callback: any): void;
    removeEventListener(type: any, callback: any): void;
    dispatchEvent(event: BeamEvent): boolean;
}
