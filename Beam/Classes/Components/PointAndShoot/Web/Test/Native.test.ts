import {Native} from "../Native"
import {BeamDocumentMock, BeamHTMLIFrameElementMock, BeamLocationMock} from "./BeamMocks"
import {BeamWindowMock} from "./BeamWindowMock"

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
  const windowMock = new BeamWindowMock(testDocument, new BeamLocationMock({href}))
  windowMock.scroll(0, 0)
  return windowMock
}

test("send frame href in message", () => {
  const iframe1 = new BeamHTMLIFrameElementMock()
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
