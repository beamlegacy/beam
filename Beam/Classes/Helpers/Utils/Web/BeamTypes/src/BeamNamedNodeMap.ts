export class BeamNamedNodeMap extends Object implements NamedNodeMap {
  [index: number]: Attr

  private readonly attrs: Attr[] = []

  constructor(props = {}) {
    super()
    for (const p in props) {
      if (Object.prototype.hasOwnProperty.call(props, p)) {
        const attr: Attr = {
          ATTRIBUTE_NODE: 0,
          CDATA_SECTION_NODE: 0,
          COMMENT_NODE: 0,
          DOCUMENT_FRAGMENT_NODE: 0,
          DOCUMENT_NODE: 0,
          DOCUMENT_POSITION_CONTAINED_BY: 0,
          DOCUMENT_POSITION_CONTAINS: 0,
          DOCUMENT_POSITION_DISCONNECTED: 0,
          DOCUMENT_POSITION_FOLLOWING: 0,
          DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC: 0,
          DOCUMENT_POSITION_PRECEDING: 0,
          DOCUMENT_TYPE_NODE: 0,
          ELEMENT_NODE: 0,
          ENTITY_NODE: 0,
          ENTITY_REFERENCE_NODE: 0,
          NOTATION_NODE: 0,
          PROCESSING_INSTRUCTION_NODE: 0,
          TEXT_NODE: 0,
          addEventListener(
              type: string,
              listener: EventListenerOrEventListenerObject | null,
              options: boolean | AddEventListenerOptions | undefined
          ): void {
            // TODO: Shouldn't we implement it?
          },
          appendChild<T>(newChild: T): T {
            // TODO: Shouldn't we implement it?
            return undefined
          },
          baseURI: "",
          childNodes: undefined,
          cloneNode(deep: boolean | undefined): Node {
            // TODO: Shouldn't we implement it?
            return undefined
          },
          compareDocumentPosition(other: Node): number {
            return 0
          },
          contains(other: Node | null): boolean {
            return false
          },
          dispatchEvent(event: Event): boolean {
            return false
          },
          firstChild: undefined,
          getRootNode(options: GetRootNodeOptions | undefined): Node {
            return undefined
          },
          hasChildNodes(): boolean {
            return false
          },
          insertBefore<T>(newChild: T, refChild: Node | null): T {
            return undefined
          },
          isConnected: false,
          isDefaultNamespace(namespace: string | null): boolean {
            return false
          },
          isEqualNode(otherNode: Node | null): boolean {
            return false
          },
          isSameNode(otherNode: Node | null): boolean {
            return false
          },
          lastChild: undefined,
          lookupNamespaceURI(prefix: string | null): string | null {
            return undefined
          },
          lookupPrefix(namespace: string | null): string | null {
            return undefined
          },
          namespaceURI: undefined,
          nextSibling: undefined,
          nodeName: "",
          nodeType: 0,
          nodeValue: undefined,
          ownerDocument: undefined,
          ownerElement: undefined,
          parentElement: undefined,
          parentNode: undefined,
          prefix: undefined,
          previousSibling: undefined,
          removeChild<T>(oldChild: T): T {
            return undefined
          },
          removeEventListener(
              type: string,
              callback: EventListenerOrEventListenerObject | null,
              options: EventListenerOptions | boolean | undefined
          ): void {
            // TODO: Shouldn't we implement it?
          },
          replaceChild<T>(newChild: Node, oldChild: T): T {
            return undefined
          },
          specified: false,
          textContent: undefined,
          normalize(): void {
            // TODO: Shouldn't we implement it?
          },
          name: p,
          localName: p,
          value: props[p]
        }
        this.setNamedItem(attr)
      }
    }
  }

  get length(): number {
    return this.attrs.length
  }

  getNamedItem(qualifiedName: string): Attr | null {
    return this.attrs.find((a) => a.localName === qualifiedName)
  }

  getNamedItemNS(namespace: string | null, localName: string): Attr | null {
    return this.getNamedItem(`${namespace}.${localName}`)
  }

  item(index: number): Attr | null {
    return this.attrs[index]
  }

  removeNamedItem(qualifiedName: string): Attr {
    const old = this.getNamedItem(qualifiedName)
    const index = this.attrs.indexOf(old)
    this.attrs.splice(index, 1)
    return old
  }

  removeNamedItemNS(namespace: string | null, localName: string): Attr {
    return this.removeNamedItem(namespace + "." + localName)
  }

  setNamedItem(attr: Attr): Attr | null {
    const old = this.getNamedItem(attr.localName)
    if (old) {
      this.removeNamedItem(attr.localName)
    }
    this.attrs.push(attr)
    return old
  }

  setNamedItemNS(attr: Attr): Attr | null {
    return undefined
  }

  [Symbol.iterator](): IterableIterator<Attr> {
    return this.attrs.values()
  }

  toString(): string {
    return this.attrs.map((a) => `${a.name}="${a.value}"`).join(" ")
  }
}
