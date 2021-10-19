import {PNSWindowMock} from "./PointAndShoot.test"
import { BeamWindow } from "../../../../Helpers/Utils/Web/BeamTypes"
import { BeamNamedNodeMap } from "../../../../Helpers/Utils/Web/BeamNamedNodeMap"
import { BeamUIEvent } from "../../../../Helpers/Utils/Web/BeamUIEvent"
import { BeamHTMLIFrameElementMock } from "../../../../Helpers/Utils/Web/Test/Mock/BeamHTMLIFrameElementMock"
import {PNSWindow} from "../PointAndShoot"

export class PNSBeamHTMLIFrameElementMock extends BeamHTMLIFrameElementMock {

  constructor(contentWindow: PNSWindow, attributes: NamedNodeMap = new BeamNamedNodeMap()) {
    super(contentWindow, attributes)
  }

  scrollY(delta: number): BeamUIEvent {
    const scrollEvent = super.scrollY(delta)
    const win = this.contentWindow as PNSWindowMock
    win.pns.onScroll(scrollEvent)
    return scrollEvent
  }
}
