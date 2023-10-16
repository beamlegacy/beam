import { BeamMutationObserver, BeamMutationRecord, BeamNode, BeamResizeObserver } from "@beam/native-beamtypes";
export declare class BeamMutationObserverMock implements BeamMutationObserver {
    fn: any;
    constructor(fn: any);
    private targets;
    disconnect(): void;
    observe(target: BeamNode, options?: MutationObserverInit): void;
    takeRecords(): BeamMutationRecord[];
}
export declare class BeamResizeObserverMock implements BeamResizeObserver {
    fn: any;
    constructor(fn: any);
    observe(): void;
    unobserve(): void;
    disconnect(): void;
}
