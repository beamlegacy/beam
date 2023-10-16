import { BeamEventTargetMock } from "./BeamEventTargetMock";
import { BeamElement, BeamNode, BeamNodeType, BeamRect } from "@beam/native-beamtypes";
export declare class BeamNodeMock extends BeamEventTargetMock implements BeamNode {
    readonly nodeName: string;
    readonly nodeType: BeamNodeType;
    static readonly ELEMENT_NODE = BeamNodeType.element;
    static readonly TEXT_NODE = BeamNodeType.text;
    static readonly PROCESSING_INSTRUCTION_NODE = BeamNodeType.processing_instruction;
    static readonly COMMENT_NODE = BeamNodeType.comment;
    static readonly DOCUMENT_NODE = BeamNodeType.document;
    static readonly DOCUMENT_TYPE_NODE = BeamNodeType.document_type;
    static readonly DOCUMENT_FRAGMENT_NODE = BeamNodeType.document_fragment;
    childNodes: BeamNode[];
    parentNode?: BeamNode;
    parentElement?: BeamElement;
    isConnected: boolean;
    /**
     * @deprecated Not standard, for test purpose
     * Relative bounds
     */
    bounds: BeamRect;
    constructor(nodeName: string, nodeType: BeamNodeType, props?: {});
    muted?: boolean;
    paused?: boolean;
    webkitSetPresentationMode(BeamWebkitPresentationMode: any): void;
    offsetHeight: number;
    offsetWidth: number;
    appendChild(node: BeamNode): BeamNode;
    removeChild(el: BeamNode): void;
    contains(el: BeamNode): boolean;
    get textContent(): string;
}
