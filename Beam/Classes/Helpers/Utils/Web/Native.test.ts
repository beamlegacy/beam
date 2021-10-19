import {Native} from "./Native"
import {BeamWindowMock} from "./Test/Mock/BeamWindowMock"
import {BeamLocationMock} from "./Test/Mock/BeamLocationMock"
import {BeamDocumentMock} from "./Test/Mock/BeamDocumentMock"
import {PNSWindowMock} from "../../../Components/PointAndShoot/Web/Test/PointAndShoot.test"
import {PNSBeamHTMLIFrameElementMock} from "../../../Components/PointAndShoot/Web/Test/PNSBeamHTMLIFrameElementMock"
import {BeamDocument, BeamLocation} from "./BeamTypes"

class TestWindowMock extends BeamWindowMock<any> {
  constructor() {
    super()
  }
  create(doc: BeamDocument, location: BeamLocation): TestWindowMock {
    return new TestWindowMock();
  }
}

/**
 *
 * @param href {string}
 * @param frameEls {BeamHTMLElement[]}
 * @return {BeamWindowMock}
 */
function nativeTestBed(href, frameEls = []) {
  const scrollData = {
    scrollWidth: 800,
    scrollHeight: 0,
    offsetWidth: 800,
    offsetHeight: 0,
    clientWidth: 800,
    clientHeight: 0
  }
  const styleData = {
    style: {
      zoom: "1"
    }
  }
  const testDocument = new BeamDocumentMock({
    body: {
      ...styleData,
      ...scrollData
    },
    documentElement: scrollData,
    querySelectorAll: (selector) => {
      if (selector === "iframe") {
        return frameEls
      }
    }
  })
  const windowMock = new PNSWindowMock(testDocument, new BeamLocationMock({href}))
  windowMock.scroll(0, 0)
  return windowMock
}

test("send frame href in message", () => {
  const mainWindow = new TestWindowMock()
  const iframe1 = new PNSBeamHTMLIFrameElementMock(mainWindow)
  Object.assign(iframe1, {
    src: "https://iframe1.com/about-us.html",
    clientLeft: 101,
    clientTop: 102,
    width: 800,
    height: 600
  })
  const iframes = [iframe1]
  const win = nativeTestBed(iframe1.src, iframes)
  const native = new Native(win)
  expect(native.href).toEqual(iframe1.src)

  const frameInfo = {href: iframe1.src, bounds: {x: iframe1.clientLeft, y: iframe1.clientTop, width: iframe1.width}}
  native.sendMessage("frameBounds", frameInfo)
  const mockMessageHandlers = win.webkit.messageHandlers
  expect(mockMessageHandlers.pointAndShoot_frameBounds.events.length).toEqual(1)
  expect(mockMessageHandlers.pointAndShoot_frameBounds.events[0]).toEqual({
    name: "postMessage",
    payload: {...frameInfo, href: iframe1.src}
  })
})
