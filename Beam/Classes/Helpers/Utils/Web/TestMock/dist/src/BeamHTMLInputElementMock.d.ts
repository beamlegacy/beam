import { BeamHTMLInputElement } from "@beam/native-beamtypes";
import { BeamHTMLElementMock } from "./BeamHTMLElementMock";
export declare class BeamHTMLInputElementMock extends BeamHTMLElementMock implements BeamHTMLInputElement {
    focus(): void;
    srcset?: string;
    currentSrc?: string;
    src?: string;
    id?: string;
    value: string;
    get type(): string;
    set type(value: string);
}
