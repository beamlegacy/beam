import { BeamNodeMock } from "./BeamNodeMock";
export declare class BeamCharacterDataMock extends BeamNodeMock {
    readonly data: string;
    constructor(data: string, props?: {});
    get length(): number;
    toString(): string;
}
