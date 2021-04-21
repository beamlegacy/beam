import {Native} from "./Native"
import {BeamDocumentMock, BeamHTMLIFrameElementMock} from "./Test/BeamMocks"
import {TestWindow} from "./Test/TestWindow"

/**
 *
 * @param origin {string}
 * @param frameEls {BeamHTMLElement[]}
 * @return {TestWindow}
 */
function nativeTestBed(origin, frameEls = []) {
  const scrollData = {
    scrollWidth: 800, scrollHeight: 0,
    offsetWidth: 800, offsetHeight: 0,
    clientWidth: 800, clientHeight: 0,
  }
  const testDocument = new BeamDocumentMock({
    body: scrollData,
    documentElement: scrollData,
    querySelectorAll: (selector) => {
      if (selector === "iframe") {
        return frameEls
      }
    }
  })
  return new TestWindow({origin, scrollX: 0, scrollY: 0, document: testDocument})
}

test("send frame href in message", () => {
  const iframe1 = new BeamHTMLIFrameElementMock({src: "https://iframe1.com", clientLeft: 101, clientTop: 102, width: 800, height: 600})
  const iframes = [iframe1]
  const win = nativeTestBed(iframe1.src, iframes)
  const native = new Native(win)
  expect(native.origin).toEqual(iframe1.src)

  let frameInfo = {href: iframe1.src, bounds: {x: iframe1.clientLeft, y: iframe1.clientTop, width: iframe1.width}}
  native.sendMessage("frameBounds", frameInfo)
  const mockMessageHandlers = win.webkit.messageHandlers
  expect(mockMessageHandlers.pointAndShoot_frameBounds.events.length).toEqual(1)
  expect(mockMessageHandlers.pointAndShoot_frameBounds.events[0]).toEqual({name: "postMessage", payload: {...frameInfo, origin: iframe1.src}})
})
