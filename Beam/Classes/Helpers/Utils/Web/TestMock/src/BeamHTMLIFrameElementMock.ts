import {BeamHTMLIFrameElement, BeamWindow} from "@beam/native-beamtypes"
import {BeamWindowMock} from "./BeamWindowMock"
import {BeamUIEvent, BeamNamedNodeMap} from "@beam/native-beamtypes"
import {BeamHTMLElementMock} from "./BeamHTMLElementMock"

export class BeamHTMLIFrameElementMock extends BeamHTMLElementMock implements BeamHTMLIFrameElement {
  src: string

  constructor(public contentWindow: BeamWindow<any>, attributes: NamedNodeMap = new BeamNamedNodeMap()) {
    super("iframe", attributes)
  }
  focus() {
    throw new Error("Method not implemented.")
  }
  srcset?: string
  currentSrc?: string
  id?: string

  setAttribute(qualifiedName: string, value: string): void {
    throw new Error("Method not implemented.")
  }

  getAttribute(qualifiedName: string): string {
    throw new Error("Method not implemented.")
  }

  nodeValue: any

  /**
   * @param delta {number} positive or negative scroll delta
   * @return the scroll event
   */
  scrollY(delta: number): BeamUIEvent {
    this.clientTop += delta
    const win = this.contentWindow as BeamWindowMock<any>
    win.scroll(0, win.scrollY + delta)
    const scrollEvent = new BeamUIEvent()
    Object.assign(scrollEvent, {name: "scroll"})
    return scrollEvent
  }
}
