import { BeamHTMLTextAreaElement } from "@beam/native-beamtypes";
import { BeamHTMLElementMock } from "./BeamHTMLElementMock";
export declare class BeamHTMLTextAreaElementMock extends BeamHTMLElementMock implements BeamHTMLTextAreaElement {
    focus(): void;
    srcset?: string;
    currentSrc?: string;
    src?: string;
    id?: string;
    value: string;
}
