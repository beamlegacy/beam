import { BeamCrypto, BeamHTMLElement, BeamLocation, BeamMessageHandler, BeamVisualViewport, BeamWebkit, BeamWindow } from "@beam/native-beamtypes";
import { BeamEventTargetMock } from "./BeamEventTargetMock";
import { BeamDocumentMock } from "./BeamDocumentMock";
export declare class MessageHandlerMock implements BeamMessageHandler {
    events: any[];
    postMessage(payload: any): void;
}
export declare class BeamVisualViewportMock extends BeamEventTargetMock implements BeamVisualViewport {
    height: number;
    offsetLeft: number;
    offsetTop: number;
    pageLeft: number;
    pageTop: number;
    scale: number;
    width: number;
}
export declare class BeamCryptoMock implements BeamCrypto {
    getRandomValues(buffer: []): number[];
}
export declare abstract class BeamWindowMock<M> extends BeamEventTargetMock implements BeamWindow<M> {
    visualViewport: BeamVisualViewportMock;
    readonly document: BeamDocumentMock;
    protected constructor(doc?: BeamDocumentMock, location?: BeamLocation);
    scrollTo(xCoord: number, yCoord: number): void;
    onunload: () => void;
    matchMedia(arg0: string): void;
    addListener: () => void;
    crypto: BeamCryptoMock;
    frameElement: any;
    frames: any;
    scroll(xCoord: number, yCoord: number): void;
    webkit: BeamWebkit<M>;
    abstract create(doc: BeamDocumentMock, location: BeamLocation): BeamWindowMock<M>;
    getEventListeners(_win: BeamWindow<any>): {};
    getComputedStyle(el: BeamHTMLElement, pseudo?: string): CSSStyleDeclaration;
    open(url?: string, name?: string, specs?: string, replace?: boolean): BeamWindow<M> | null;
    innerHeight: any;
    innerWidth: any;
    location: any;
    origin: any;
    scrollX: number;
    scrollY: number;
}
