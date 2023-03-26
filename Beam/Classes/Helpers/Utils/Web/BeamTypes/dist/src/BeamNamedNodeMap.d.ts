export declare class BeamNamedNodeMap extends Object implements NamedNodeMap {
    [index: number]: Attr;
    private readonly attrs;
    constructor(props?: {});
    get length(): number;
    getNamedItem(qualifiedName: string): Attr | null;
    getNamedItemNS(namespace: string | null, localName: string): Attr | null;
    item(index: number): Attr | null;
    removeNamedItem(qualifiedName: string): Attr;
    removeNamedItemNS(namespace: string | null, localName: string): Attr;
    setNamedItem(attr: Attr): Attr | null;
    setNamedItemNS(attr: Attr): Attr | null;
    [Symbol.iterator](): IterableIterator<Attr>;
    toString(): string;
}
