import { BeamHTMLIFrameElement, BeamWindow } from "@beam/native-beamtypes";
import { BeamUIEvent } from "@beam/native-beamtypes";
import { BeamHTMLElementMock } from "./BeamHTMLElementMock";
export declare class BeamHTMLIFrameElementMock extends BeamHTMLElementMock implements BeamHTMLIFrameElement {
    contentWindow: BeamWindow<any>;
    src: string;
    constructor(contentWindow: BeamWindow<any>, attributes?: NamedNodeMap);
    focus(): void;
    srcset?: string;
    currentSrc?: string;
    id?: string;
    setAttribute(qualifiedName: string, value: string): void;
    getAttribute(qualifiedName: string): string;
    nodeValue: any;
    /**
     * @param delta {number} positive or negative scroll delta
     * @return the scroll event
     */
    scrollY(delta: number): BeamUIEvent;
}
