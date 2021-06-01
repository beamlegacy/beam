import {Native} from "./Native"
import {BeamDocumentMock, BeamHTMLIFrameElementMock} from "./Test/BeamMocks"
import {BeamWindowMock} from "./Test/BeamWindowMock"

/**
 *
 * @param href {string}
 * @param frameEls {BeamHTMLElement[]}
 * @return {BeamWindowMock}
 */
function nativeTestBed(href, frameEls = []) {
  const scrollData = {
    scrollWidth: 800, scrollHeight: 0,
    offsetWidth: 800, offsetHeight: 0,
    clientWidth: 800, clientHeight: 0,
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
  return new BeamWindowMock({href, scrollX: 0, scrollY: 0, document: testDocument})
}

test("send frame href in message", () => {
  const iframe1 = new BeamHTMLIFrameElementMock({src: "https://iframe1.com/about-us.html", clientLeft: 101, clientTop: 102, width: 800, height: 600})
  const iframes = [iframe1]
  const win = nativeTestBed(iframe1.src, iframes)
  const native = new Native(win)
  expect(native.href).toEqual(iframe1.src)

  let frameInfo = {href: iframe1.src, bounds: {x: iframe1.clientLeft, y: iframe1.clientTop, width: iframe1.width}}
  native.sendMessage("frameBounds", frameInfo)
  const mockMessageHandlers = win.webkit.messageHandlers
  expect(mockMessageHandlers.pointAndShoot_frameBounds.events.length).toEqual(1)
  expect(mockMessageHandlers.pointAndShoot_frameBounds.events[0]).toEqual({name: "postMessage", payload: {...frameInfo, href: iframe1.src}})
})
