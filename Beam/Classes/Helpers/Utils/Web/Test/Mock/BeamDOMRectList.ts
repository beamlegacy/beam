export class BeamDOMRectList implements DOMRectList {
  constructor(private list: DOMRect[]) {
  }

  [index: number]: DOMRect

  get length(): number {
    return this.list.length
  }

  [Symbol.iterator](): IterableIterator<DOMRect> {
    return this.list.values()
  }

  item(index: number): DOMRect | null {
    return this.list[index]
  }
}
