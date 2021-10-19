import {BeamElement} from "../../BeamTypes"

export class BeamHTMLCollection<E extends BeamElement = BeamElement> /*implements HTMLCollection*/ {
  constructor(private values: E[]) {
  }

  [index: number]: E

  get length(): number {
    return this.values.length
  }

  [Symbol.iterator](): IterableIterator<E> {
    return this.values.values()
  }

  item(index: number): E | null {
    return this.values[index]
  }

  namedItem(name: string): E | null {
    return this.item(parseInt(name, 10))
  }
}
