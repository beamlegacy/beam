import { BeamNode, BeamRange, BeamSelection } from "@beam/native-beamtypes";
export declare class BeamSelectionMock implements BeamSelection {
    constructor(nodeName: string, attributes?: {});
    anchorNode: BeamNode;
    focusNode: BeamNode;
    anchorOffset: 0;
    focusOffset: 0;
    isCollapsed: false;
    rangeCount: number;
    type: "Range";
    caretBidiLevel: 0;
    private rangelist;
    addRange(range: BeamRange): void;
    collapse(node: BeamNode, offset?: number): void;
    collapseToEnd(): void;
    collapseToStart(): void;
    containsNode(node: BeamNode, allowPartialContainment?: boolean): boolean;
    deleteFromDocument(): void;
    empty(): void;
    extend(node: BeamNode, offset?: number): void;
    getRangeAt(index: number): BeamRange;
    removeAllRanges(): void;
    removeRange(range: BeamRange): void;
    selectAllChildren(node: BeamNode): void;
    setBaseAndExtent(anchorNode: BeamNode, anchorOffset: number, focusNode: BeamNode, focusOffset: number): void;
    setPosition(node: BeamNode, offset?: number): void;
    toString(): string;
}
