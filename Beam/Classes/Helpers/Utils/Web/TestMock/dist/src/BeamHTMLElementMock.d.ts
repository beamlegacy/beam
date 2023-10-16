import { BeamHTMLElement } from "@beam/native-beamtypes";
import { BeamElementMock } from "./BeamElementMock";
export declare class BeamHTMLElementMock extends BeamElementMock implements BeamHTMLElement {
    querySelectorResult: {};
    dataset: {
        "beam-mock": string;
    };
    isConnected: boolean;
    constructor(nodeName: string, attributes?: {});
    parentElement?: BeamHTMLElement;
    setQuerySelectorResult(query: string, element: BeamHTMLElementMock): void;
    querySelectorAll(query: string): BeamHTMLElementMock[];
    querySelector(query: string): BeamHTMLElementMock;
    removeAttribute(pointDatasetKey: any): void;
    setAttribute(qualifiedName: string, value: string): void;
    getAttribute(qualifiedName: string): string;
    nodeValue: any;
    get innerText(): string;
    set innerText(text: string);
}
