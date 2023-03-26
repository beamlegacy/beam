export declare class BeamDOMRectList implements DOMRectList {
    private list;
    constructor(list: DOMRect[]);
    [index: number]: DOMRect;
    get length(): number;
    [Symbol.iterator](): IterableIterator<DOMRect>;
    item(index: number): DOMRect | null;
}
